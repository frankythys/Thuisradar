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

/// De activiteiten van één dag: verblijven uit de tijdlijn en ritten uit de
/// echte metingen, chronologisch (oudste eerst). Een "rit" met minder dan
/// [minTripMeters] beweging is ruis en valt weg.
List<DrivingActivity> buildDayActivities(
  List<TimelineEntry> entries,
  List<TrackPoint> points, {
  double minTripMeters = 100,
}) {
  final activities = <DrivingActivity>[];
  for (final entry in entries) {
    if (entry.kind != TimelineKind.stop) continue;
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
  for (final track in buildTripTracks(points)) {
    final meters = trackMeters(track);
    if (meters < minTripMeters) continue;
    activities.add(
      DrivingActivity(
        kind: DrivingActivityKind.trip,
        start: track.first.recordedAt,
        end: track.last.recordedAt,
        latitude: track.last.latitude,
        longitude: track.last.longitude,
        distanceMeters: meters,
        fromLatitude: track.first.latitude,
        fromLongitude: track.first.longitude,
      ),
    );
  }
  return activities..sort((a, b) => a.start.compareTo(b.start));
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
/// die rit, zodat de kaart op de rit zelf kan inzoomen. Leeg als er geen
/// punten in dat tijdsvak vallen.
List<TrackPoint> activityTrack(DrivingActivity activity, List<TrackPoint> points) => [
  for (final point in points)
    if (!point.recordedAt.isBefore(activity.start) && !point.recordedAt.isAfter(activity.end)) point,
];

