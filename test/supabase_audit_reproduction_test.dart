import 'package:flutter_test/flutter_test.dart';
import 'package:thuisradar/features/location/domain/track_point.dart';
import 'package:thuisradar/features/location/domain/timeline.dart';
import 'package:thuisradar/features/driving/domain/driving_activity.dart';

// Read-only Supabase audit, 2026-10-11. Actual endpoints of three
// constant-coordinate runs from Liam's 2026-10-07 18:00-18:15 UTC history.
// Intermediate samples have identical coordinates; retained endpoints
// preserve each run's duration. Onmogelijke sprongen mogen geen rit vormen.
void main() {
  test('opgeslagen onmogelijke locatieveranderingen worden geen rit van 8873 km', () {
    TrackPoint p(String at, double lat, double lng, [double? speed = 0]) => TrackPoint(
      latitude: lat,
      longitude: lng,
      recordedAt: DateTime.parse('2026-10-07T${at}Z'),
      speedMps: speed,
    );
    final points = [
      p('18:00:00.689', 37.4219983, -122.084),
      p('18:03:09.799', 37.4219983, -122.084),
      p('18:05:17.880', 51.21993, 4.41499, null),
      p('18:07:50.976', 51.21993, 4.41499),
      p('18:08:20.994', 51.1803283, 4.3927183, null),
      p('18:14:48.227', 51.1803283, 4.3927183),
    ];
    final activities = buildDayActivities(buildTimeline(points), points);
    expect(activities.where((a) => a.kind == DrivingActivityKind.trip), isEmpty);
  });
}
