import 'track_point.dart';

/// Hoe lang mag een gat in het spoor zijn voor we het onderbreken? Dezelfde
/// grens als het rijoverzicht: vanaf vijf minuten zonder meting weten we niet
/// hoe er gereden is.
const kMaxTrackGap = Duration(minutes: 5);

/// Splitst GPS-punten in aaneengesloten stukken: zodra er meer dan [maxGap]
/// tussen twee metingen zit, begint een nieuw stuk. Die twee punten worden dus
/// nooit met een rechte lijn verbonden — een auto rijdt over de weg, niet
/// dwars door de stad. Een stuk met één punt levert niets op: daar valt geen
/// route mee te tekenen.
List<List<TrackPoint>> splitTrackGaps(List<TrackPoint> points, {Duration maxGap = kMaxTrackGap}) {
  final segments = <List<TrackPoint>>[];
  var current = <TrackPoint>[];
  for (final point in points) {
    if (current.isNotEmpty && point.recordedAt.difference(current.last.recordedAt) > maxGap) {
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
