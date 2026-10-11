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

  /// Met [from]/[to] (de kalenderdag) mogen [entries] en [points] verder
  /// reiken dan de dag zelf: dan hoort een rit bij de dag waarop hij vertrekt
  /// en blijft hij heel, ook over middernacht. Verblijven tonen we op elke dag
  /// die ze raken, afgeknipt op die dag.
  factory DayDriving.build(
    List<TimelineEntry> entries,
    List<TrackPoint> points, {
    DateTime? from,
    DateTime? to,
  }) {
    // Eén keer filteren; buildDayActivities en het spoor gebruiken dezelfde
    // punten, zodat afstand en ritkaart altijd over hetzelfde spoor gaan.
    final clean = withoutSpikes(points);
    final activities = [
      for (final activity in buildDayActivities(entries, clean)) ?_withinDay(activity, from, to),
    ];
    return DayDriving._(activities, [
      for (final activity in activities)
        activity.kind == DrivingActivityKind.trip ? _tripTrack(clean, activity) : const [],
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

/// Een rit telt op zijn vertrekdag; een verblijf op elke dag die het raakt,
/// afgeknipt op die dag. Zonder grenzen blijft alles staan.
DrivingActivity? _withinDay(DrivingActivity activity, DateTime? from, DateTime? to) {
  if (from == null || to == null) return activity;
  if (activity.kind == DrivingActivityKind.trip) {
    return !activity.start.isBefore(from) && activity.start.isBefore(to) ? activity : null;
  }
  if (!activity.end.isAfter(from) || !activity.start.isBefore(to)) return null;
  if (!activity.start.isBefore(from) && !activity.end.isAfter(to)) return activity;
  return DrivingActivity(
    kind: activity.kind,
    start: activity.start.isBefore(from) ? from : activity.start,
    end: activity.end.isAfter(to) ? to : activity.end,
    latitude: activity.latitude,
    longitude: activity.longitude,
    placeName: activity.placeName,
  );
}

/// Het spoor van een rit. Werd de aankomst over een meetgat overbrugd
/// (tunnel, parkeergarage), dan eindigt het spoor op de bestemming zelf: zo
/// staat het eindpunt op de kaart waar de rit echt eindigde, niet op de
/// laatste straat met GPS. De routekaart tekent over dat gat geen lijn.
List<TrackPoint> _tripTrack(List<TrackPoint> clean, DrivingActivity trip) {
  final track = _window(clean, trip.start, trip.end);
  if (track.isEmpty || !trip.end.isAfter(track.last.recordedAt)) return track;
  final last = track.last;
  if (last.latitude == trip.latitude && last.longitude == trip.longitude) return track;
  return [...track, TrackPoint(latitude: trip.latitude, longitude: trip.longitude, recordedAt: trip.end)];
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
