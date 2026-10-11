import '../../location/domain/timeline.dart';
import '../../location/domain/track_point.dart';
import '../../location/domain/track_segments.dart';
import 'driving_activity.dart';

/// De activiteiten van één dag mét het routespoor van elke rit, één keer
/// berekend. Schermen tonen dit bij elke klok-tik opnieuw; zonder deze cache
/// filterde en sorteerde elke rit alle punten van de dag opnieuw.
/// Puur: geen Flutter of Supabase.
class DayDriving {
  DayDriving._(this.activities, this._tracks);

  factory DayDriving.build(List<TimelineEntry> entries, List<TrackPoint> points) {
    // Eén keer filteren; buildDayActivities en het spoor gebruiken dezelfde
    // punten, zodat afstand en ritkaart altijd over hetzelfde spoor gaan.
    final clean = withoutSpikes(points);
    final activities = buildDayActivities(entries, clean);
    return DayDriving._(activities, [
      for (final activity in activities)
        activity.kind == DrivingActivityKind.trip ? _window(clean, activity.start, activity.end) : const [],
    ]);
  }

  /// Chronologisch, oudste eerst.
  final List<DrivingActivity> activities;
  final List<List<TrackPoint>> _tracks;

  /// Het routespoor van [activities][index]; leeg bij een verblijf.
  List<TrackPoint> trackAt(int index) => _tracks[index];

  /// Alle ritten van de dag als aaneengesloten stukken voor de dagkaart.
  late final List<List<TrackPoint>> routes = [
    for (var i = 0; i < activities.length; i++)
      if (activities[i].kind == DrivingActivityKind.trip) ...splitTrackGaps(_tracks[i]),
  ];
}

/// De punten met tijdstip in [start, end]; [sorted] is oudste eerst.
List<TrackPoint> _window(List<TrackPoint> sorted, DateTime start, DateTime end) {
  final from = _firstNotBefore(sorted, start);
  var to = from;
  while (to < sorted.length && !sorted[to].recordedAt.isAfter(end)) {
    to++;
  }
  return sorted.sublist(from, to);
}

int _firstNotBefore(List<TrackPoint> sorted, DateTime time) {
  var low = 0;
  var high = sorted.length;
  while (low < high) {
    final mid = (low + high) >> 1;
    if (sorted[mid].recordedAt.isBefore(time)) {
      low = mid + 1;
    } else {
      high = mid;
    }
  }
  return low;
}
