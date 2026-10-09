import '../../location/domain/motion_filter.dart';
import '../../location/domain/timeline.dart';
import '../../location/domain/track_point.dart';
import '../../location/domain/track_segments.dart';

/// Soort activiteit in de dagtijdlijn van een gezinslid.
enum DrivingActivityKind { trip, stay }

/// Eén activiteit op een dag: een verplaatsing (rit) of een verblijf op één
/// plek. Puur model, los van Flutter en Supabase, zodat het te testen is.
class DrivingActivity {
  const DrivingActivity({
    required this.kind,
    required this.start,
    required this.end,
    required this.latitude,
    required this.longitude,
    this.distanceMeters,
    this.fromLatitude,
    this.fromLongitude,
    this.placeName,
  });

  final DrivingActivityKind kind;
  final DateTime start;
  final DateTime end;

  /// Aankomstpunt van een rit, of het middelpunt van een verblijf.
  final double latitude;
  final double longitude;

  /// Afgelegde afstand in meter (enkel bij een rit).
  final double? distanceMeters;

  /// Vertrekpunt van een rit (de vorige stop), indien bekend.
  final double? fromLatitude;
  final double? fromLongitude;

  /// Naam van een eigen plaats bij een verblijf, indien binnen een zone.
  final String? placeName;

  Duration get duration => end.difference(start);
}

/// Een rit is een aaneengesloten reeks metingen waarin de wagen rijdt. De reeks
/// stopt waar het toestel minstens [stillAfter] op dezelfde plek bleef (een
/// stop) of waar de metingen wegvallen ([maxGap]). Zo wordt een dag met veel
/// korte stops niet één "rit" van uren en wordt er nooit een gat overbrugd.
/// Puur: geen Flutter of Supabase. Resultaat is chronologisch (oudste eerst).
List<List<TrackPoint>> buildTripTracks(
  List<TrackPoint> points, {
  Duration stillAfter = kMinStop,
  double stillRadiusMeters = kStopRadiusMeters,
  Duration maxGap = kMaxTrackGap,
}) {
  final trips = <List<TrackPoint>>[];
  var current = <TrackPoint>[];
  TrackPoint? still;

  void close() {
    if (current.length > 1) trips.add(current);
    current = <TrackPoint>[];
  }

  for (final point in points) {
    if (current.isNotEmpty && point.recordedAt.difference(current.last.recordedAt) > maxGap) {
      close();
      still = null;
    }
    if (still == null) {
      still = point;
    } else if (_legMeters(still, point) > stillRadiusMeters) {
      // Hij rijdt weer: de stilte begint opnieuw te tellen.
      still = point;
    } else if (point.recordedAt.difference(still.recordedAt) >= stillAfter) {
      // Lang genoeg op dezelfde plek: de rit is afgelopen.
      close();
      still = point;
    }
    current.add(point);
  }
  close();
  return trips;
}

/// Een kort meetgat vlak voor de aankomst (een tunnel, een parkeergarage, even
/// geen signaal) hoort nog bij de rit. Eindigt een rit minder dan [kArrivalGap]
/// voor een verblijf begint, dan is dat verblijf de bestemming: de rit krijgt de
/// plek, de aankomsttijd en de laatste afstand tot daar. Grotere gaten (toestel
/// uit) overbruggen we niet — dan blijven het losse ritten.
const kArrivalGap = Duration(minutes: 20);

/// De activiteiten van één dag: verblijven uit de tijdlijn en ritten uit de
/// echte metingen, chronologisch (oudste eerst). Een "rit" met minder dan
/// [minTripMeters] beweging is ruis en valt weg.
List<DrivingActivity> buildDayActivities(
  List<TimelineEntry> entries,
  List<TrackPoint> points, {
  double minTripMeters = 100,
}) {
  final activities = <DrivingActivity>[];
  final stops = <TimelineEntry>[];
  for (final entry in entries) {
    if (entry.kind != TimelineKind.stop) continue;
    stops.add(entry);
    activities.add(
      DrivingActivity(
        kind: DrivingActivityKind.stay,
        start: entry.start,
        end: entry.end,
        latitude: entry.latitude,
        longitude: entry.longitude,
        placeName: entry.placeName,
      ),
    );
  }
  for (final raw in buildTripTracks(points)) {
    // Enkel het stuk waarin echt gereden wordt: zonder de minuten stilstaan
    // ervoor (nog thuis) en erna (al aangekomen). Een spoor dat alleen uit
    // stilstaan bestaat, is geen rit.
    final track = trimStill(raw);
    if (track.length < 2 || trackMeters(track) < minTripMeters) continue;
    final last = track.last;
    // De bestemming: het eerstvolgende verblijf dat binnen [kArrivalGap] na de
    // laatste meting begint. Zo eindigt de rit op de plek waar hij stopte, ook
    // als de GPS de laatste meters (tunnel) miste.
    TimelineEntry? arrival;
    for (final stop in stops) {
      if (stop.start.isBefore(last.recordedAt)) continue;
      if (stop.start.difference(last.recordedAt) > kArrivalGap) continue;
      if (arrival == null || stop.start.isBefore(arrival.start)) arrival = stop;
    }
    final endLatitude = arrival?.latitude ?? last.latitude;
    final endLongitude = arrival?.longitude ?? last.longitude;
    final endTime = arrival?.start ?? last.recordedAt;

    var meters = trackMeters(track);
    if (arrival != null) {
      meters += distanceMeters(last.latitude, last.longitude, endLatitude, endLongitude);
    }
    if (meters < minTripMeters) continue;
    // Een "rit" die eindigt waar ze begon (binnen de stopstraal) ging nergens
    // heen: het zijn GPS-uitschieters op één plek, geen echte verplaatsing.
    if (distanceMeters(track.first.latitude, track.first.longitude, endLatitude, endLongitude) <
        kStopRadiusMeters) {
      continue;
    }
    activities.add(
      DrivingActivity(
        kind: DrivingActivityKind.trip,
        start: track.first.recordedAt,
        end: endTime,
        latitude: endLatitude,
        longitude: endLongitude,
        distanceMeters: meters,
        fromLatitude: track.first.latitude,
        fromLongitude: track.first.longitude,
      ),
    );
  }
  return activities..sort((a, b) => a.start.compareTo(b.start));
}

/// Knipt het stilstaan aan begin en einde van een spoor weg: vertrek is de
/// laatste meting nog binnen [radiusMeters] van het beginpunt, aankomst de
/// eerste meting al binnen [radiusMeters] van het eindpunt.
List<TrackPoint> trimStill(List<TrackPoint> track, {double radiusMeters = kStopRadiusMeters}) {
  if (track.length < 2) return track;
  var first = 0;
  while (first + 1 < track.length && _legMeters(track.first, track[first + 1]) <= radiusMeters) {
    first++;
  }
  var last = track.length - 1;
  while (last - 1 > first && _legMeters(track.last, track[last - 1]) <= radiusMeters) {
    last--;
  }
  return track.sublist(first, last + 1);
}

/// Afgelegde afstand langs een reeks metingen (haversine per been).
double trackMeters(List<TrackPoint> track) {
  var meters = 0.0;
  for (var index = 1; index < track.length; index++) {
    meters += _legMeters(track[index - 1], track[index]);
  }
  return meters;
}

double _legMeters(TrackPoint a, TrackPoint b) =>
    distanceMeters(a.latitude, a.longitude, b.latitude, b.longitude);

/// De GPS-punten tussen vertrek en aankomst van [activity]: de echte route van
/// die rit, zodat de kaart op de rit zelf kan inzoomen. Zonder GPS-sprongen,
/// zodat er geen zigzag over de kaart loopt. Leeg voor een verblijf of als er
/// geen punten in dat tijdsvak vallen.
List<TrackPoint> activityTrack(DrivingActivity activity, List<TrackPoint> points) {
  if (activity.kind != DrivingActivityKind.trip) return const [];
  return withoutSpikes([
    for (final point in points)
      if (!point.recordedAt.isBefore(activity.start) && !point.recordedAt.isAfter(activity.end)) point,
  ]);
}

/// Alle ritten van een dag als routestukken, zonder het stilstaan ertussen.
/// Voor de dagkaart: rondlopen in een winkel of binnenshuis-GPS is geen route
/// en gaf een wirwar van lijnen op de plek waar je stond.
List<List<TrackPoint>> dayRoutes(List<TimelineEntry> entries, List<TrackPoint> points) => [
  for (final activity in buildDayActivities(entries, points))
    if (activity.kind == DrivingActivityKind.trip) ...splitTrackGaps(activityTrack(activity, points)),
];

/// Hoger dan dit (≈ 160 km/u) tussen twee metingen is geen rijden maar een
/// GPS-sprong (bv. even een zendmastpositie).
const kMaxPlausibleSpeedMps = 45.0;

/// Laat metingen weg die onmogelijk snel van de vorige wegspringen. Een sprong
/// heen en terug wordt zo één weggelaten punt i.p.v. twee lange lijnen.
List<TrackPoint> withoutSpikes(List<TrackPoint> track, {double maxSpeedMps = kMaxPlausibleSpeedMps}) {
  final kept = <TrackPoint>[];
  for (final point in track) {
    if (kept.isNotEmpty) {
      final previous = kept.last;
      final seconds = point.recordedAt.difference(previous.recordedAt).inMilliseconds / 1000;
      final meters = _legMeters(previous, point);
      if (seconds > 0 && meters / seconds > maxSpeedMps && meters > kStopRadiusMeters) continue;
    }
    kept.add(point);
  }
  return kept;
}

/// Hoogste gemeten snelheid in km/u langs [track], of null zonder bruikbare
/// GPS-snelheid. Onzinwaarden (negatief, boven 70 m/s ≈ 250 km/u) tellen niet.
int? topSpeedKmh(List<TrackPoint> track) {
  double? top;
  for (final point in track) {
    final speed = point.speedMps;
    if (speed == null || !speed.isFinite || speed < 0 || speed > 70) continue;
    if (top == null || speed > top) top = speed;
  }
  return top == null ? null : (top * 3.6).round();
}
