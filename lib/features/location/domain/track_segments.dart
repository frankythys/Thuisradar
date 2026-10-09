import 'track_point.dart';
import 'motion_filter.dart' show distanceMeters;

/// Hoe lang mag een gat in het spoor zijn voor we het onderbreken? Dezelfde
/// grens als het rijoverzicht: vanaf vijf minuten zonder meting weten we niet
/// hoe er gereden is.
const kMaxTrackGap = Duration(minutes: 5);

/// Splitst GPS-punten in aaneengesloten stukken: zodra er meer dan [maxGap]
/// tussen twee metingen zit, begint een nieuw stuk. Die twee punten worden dus
/// nooit met een rechte lijn verbonden — een auto rijdt over de weg, niet
/// dwars door de stad. Een stuk met één punt levert niets op: daar valt geen
/// route mee te tekenen.
List<List<TrackPoint>> splitTrackGaps(
  List<TrackPoint> points, {
  Duration maxGap = kMaxTrackGap,
}) {
  final segments = <List<TrackPoint>>[];
  var current = <TrackPoint>[];
  for (final point in points) {
    if (current.isNotEmpty &&
        point.recordedAt.difference(current.last.recordedAt) > maxGap) {
      _addSegment(segments, current);
      current = <TrackPoint>[];
    }
    current.add(point);
  }
  _addSegment(segments, current);
  return segments;
}

void _addSegment(List<List<TrackPoint>> segments, List<TrackPoint> segment) {
  if (segment.length > 1) segments.add(segment);
}

/// Kaartweergave is strenger dan ritgroepering: een meetgat van minuten kan
/// bij een rit horen, maar bevat geen betrouwbare geometrie om te tekenen.
List<List<TrackPoint>> routeMapSegments(List<TrackPoint> points) {
  final ordered = List<TrackPoint>.of(points)
    ..sort((a, b) => a.recordedAt.compareTo(b.recordedAt));
  final segments = <List<TrackPoint>>[];
  var current = <TrackPoint>[];
  void close() {
    // Ook losse metingen blijven zichtbaar als punten, zonder verzonnen lijn.
    if (current.isNotEmpty) segments.add(current);
    current = [];
  }

  for (final point in ordered) {
    if (!point.latitude.isFinite ||
        !point.longitude.isFinite ||
        point.latitude.abs() > 90 ||
        point.longitude.abs() > 180) {
      close();
      continue;
    }
    if (current.isNotEmpty) {
      final previous = current.last;
      final seconds =
          point.recordedAt.difference(previous.recordedAt).inMilliseconds /
          1000;
      if (seconds <= 0) continue;
      final distance = distanceMeters(
        previous.latitude,
        previous.longitude,
        point.latitude,
        point.longitude,
      );
      if (seconds > 60 || distance / seconds > 70) {
        close();
      }
    }
    current.add(point);
  }
  close();
  return segments;
}
