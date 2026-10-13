import '../../location/domain/motion_filter.dart' show distanceMeters;
import '../../location/domain/step_count.dart';
import '../../location/domain/track_point.dart';
import '../../location/domain/travel_mode.dart';
import 'driving_activity.dart';

/// Zo lang mag een auto stilstaan (file, wegenwerken, overweg) zonder dat de
/// rit eindigt. Langer is een echte stop.
const kTrafficStopMax = Duration(minutes: 20);

/// Zoveel stappen tijdens zo'n stilstand bewijzen dat iemand uitstapte: dan
/// was het een echte stop (tanken, iemand afzetten), geen file.
const kOutOfCarSteps = 30;

/// Onder deze snelheid (m/s, ±6 km/u) telt een stuk rit als stilstaan of
/// stapvoets: de wachttijd in de file.
const kWaitingMps = 1.7;

/// Bewijs van file tijdens een stilstand van 5 minuten of meer: zo'n deel
/// van de metingen meldt toch beweging (aanschuiven) ...
const _creepingShare = 0.15;
const _creepingMps = 0.5;

/// ... of de auto schoof in totaal zoveel meter op. Een geparkeerde auto (de
/// kinderen aan school afzetten) staat echt stil.
const _creepMeters = 60.0;

/// Plakt ritten weer aan elkaar die enkel door een file uit elkaar vielen.
///
/// In de file staat een auto gemakkelijk vijf minuten op dezelfde 100 m (dan
/// zag de tijdlijn een "verblijf" op de snelweg) of kruipt hij een minuut aan
/// wandeltempo (dan leek het een wandeling). Twee ritten met de auto worden
/// één rit als:
/// - er hoogstens [kTrafficStopMax] tussen zit,
/// - wat ertussen ligt geen verblijf op een eigen plaats is en geen echte
///   wandeling (met stappen),
/// - de stappenteller geen uitstappen toont ([kOutOfCarSteps]),
/// - en, als de tijdlijn er een verblijf zag (5 min op dezelfde plek), de auto
///   ondertussen toch aanschoof: anders was het een echte stop.
///
/// [activities] chronologisch (oudste eerst); [points] het opgeschoonde spoor.
/// Elke autorit krijgt daarna zijn [DrivingActivity.waiting]. Puur: geen
/// Flutter of Supabase.
List<DrivingActivity> mergeTrafficStops(List<DrivingActivity> activities, List<TrackPoint> points) {
  final result = <DrivingActivity>[];
  var index = 0;
  while (index < activities.length) {
    var trip = activities[index];
    index++;
    if (_isCarTrip(trip)) {
      // Zoek verder zolang de volgende autorit binnen de file-grens ligt.
      while (true) {
        final next = _nextCarTrip(activities, index, trip, points);
        if (next == null) break;
        trip = _merge(trip, activities.sublist(index, next + 1));
        index = next + 1;
      }
      trip = _withWaiting(trip, points);
    }
    result.add(trip);
  }
  return result;
}

/// Hoe lang er tijdens [from]–[to] stilgestaan of stapvoets gereden werd,
/// gemeten tussen opeenvolgende punten van [points] (oudste eerst).
Duration waitingTime(List<TrackPoint> points, DateTime from, DateTime to) {
  var seconds = 0.0;
  TrackPoint? previous;
  for (final point in points) {
    if (point.recordedAt.isBefore(from)) continue;
    if (point.recordedAt.isAfter(to)) break;
    final before = previous;
    previous = point;
    if (before == null) continue;
    final gap = point.recordedAt.difference(before.recordedAt).inMilliseconds / 1000;
    // Een meetgat (tunnel) zegt niets over stilstaan.
    if (gap <= 0 || gap > 120) continue;
    final meters = distanceMeters(before.latitude, before.longitude, point.latitude, point.longitude);
    if (meters / gap < kWaitingMps) seconds += gap;
  }
  return Duration(seconds: seconds.round());
}

bool _isCarTrip(DrivingActivity activity) =>
    activity.kind == DrivingActivityKind.trip && activity.mode == TravelMode.car;

/// Index van de volgende autorit die met [trip] één rit vormt, of null.
int? _nextCarTrip(List<DrivingActivity> activities, int from, DrivingActivity trip, List<TrackPoint> points) {
  var stayed = false;
  for (var index = from; index < activities.length; index++) {
    final candidate = activities[index];
    if (candidate.start.difference(trip.end) > kTrafficStopMax) return null;
    if (candidate.kind == DrivingActivityKind.stay) {
      if (candidate.placeName != null) return null; // aangekomen op een eigen plaats
      stayed = true;
      continue;
    }
    if (_isCarTrip(candidate) || candidate.mode == TravelMode.bike) {
      // Een fietsstuk tussen twee autoritten is file aan fietstempo.
      if (!_isCarTrip(candidate) && !_carFollows(activities, index + 1, trip)) return null;
      final between = [
        for (final point in points)
          if (point.recordedAt.isAfter(trip.end) && point.recordedAt.isBefore(candidate.start)) point,
      ];
      if ((stepsAlong(between) ?? 0) >= kOutOfCarSteps) return null;
      if (stayed && !_creeping(between)) return null;
      if (_isCarTrip(candidate)) return index;
      continue;
    }
    // Te voet: met echte stappen is iemand uitgestapt; anders was het kruipen.
    if ((candidate.steps ?? 0) >= kOutOfCarSteps) return null;
  }
  return null;
}

/// Schoof de auto tijdens [between] (oudste eerst) toch op, zoals in de file?
bool _creeping(List<TrackPoint> between) {
  if (between.length < 4) return false;
  final reported = between.where((p) => p.speedMps != null).toList();
  if (reported.isNotEmpty &&
      reported.where((p) => p.speedMps! >= _creepingMps).length >= reported.length * _creepingShare) {
    return true;
  }
  // Midden van de eerste helft tegenover dat van de tweede: GPS-ruis
  // (binnenshuis tot tientallen meters alle kanten op) middelt weg, gestaag
  // aanschuiven niet. Dat midden verschuift de helft van de afgelegde weg.
  final half = between.length ~/ 2;
  final (lat1, lng1) = _center(between.sublist(0, half));
  final (lat2, lng2) = _center(between.sublist(half));
  return distanceMeters(lat1, lng1, lat2, lng2) >= _creepMeters / 2;
}

(double, double) _center(List<TrackPoint> points) => (
  points.map((p) => p.latitude).reduce((a, b) => a + b) / points.length,
  points.map((p) => p.longitude).reduce((a, b) => a + b) / points.length,
);

/// Komt er binnen de file-grens nog een autorit na [from]?
bool _carFollows(List<DrivingActivity> activities, int from, DrivingActivity trip) {
  for (var index = from; index < activities.length; index++) {
    final candidate = activities[index];
    if (candidate.start.difference(trip.end) > kTrafficStopMax) return false;
    if (_isCarTrip(candidate)) return true;
  }
  return false;
}

/// [trip] plus alles in [rest] (tot en met de volgende autorit) als één rit.
DrivingActivity _merge(DrivingActivity trip, List<DrivingActivity> rest) {
  final last = rest.last;
  var meters = trip.distanceMeters ?? 0;
  var endLatitude = trip.latitude;
  var endLongitude = trip.longitude;
  for (final part in rest) {
    if (part.kind != DrivingActivityKind.trip) continue;
    // Het stukje tussen de ritten (stilstaan, kruipen) telt ook mee.
    final fromLatitude = part.fromLatitude ?? endLatitude;
    final fromLongitude = part.fromLongitude ?? endLongitude;
    meters += distanceMeters(endLatitude, endLongitude, fromLatitude, fromLongitude);
    meters += part.distanceMeters ?? 0;
    endLatitude = part.latitude;
    endLongitude = part.longitude;
  }
  return DrivingActivity(
    kind: DrivingActivityKind.trip,
    start: trip.start,
    end: last.end,
    latitude: last.latitude,
    longitude: last.longitude,
    distanceMeters: meters,
    fromLatitude: trip.fromLatitude,
    fromLongitude: trip.fromLongitude,
    mode: TravelMode.car,
  );
}

DrivingActivity _withWaiting(DrivingActivity trip, List<TrackPoint> points) => DrivingActivity(
  kind: trip.kind,
  start: trip.start,
  end: trip.end,
  latitude: trip.latitude,
  longitude: trip.longitude,
  distanceMeters: trip.distanceMeters,
  fromLatitude: trip.fromLatitude,
  fromLongitude: trip.fromLongitude,
  placeName: trip.placeName,
  mode: trip.mode,
  steps: trip.steps,
  waiting: waitingTime(points, trip.start, trip.end),
);
