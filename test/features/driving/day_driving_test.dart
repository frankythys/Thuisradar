import 'package:flutter_test/flutter_test.dart';
import 'package:thuisradar/features/driving/domain/day_driving.dart';
import 'package:thuisradar/features/driving/domain/driving_activity.dart';
import 'package:thuisradar/features/location/data/location_history_repository.dart';
import 'package:thuisradar/features/location/domain/timeline.dart';
import 'package:thuisradar/features/location/domain/track_point.dart';

void main() {
  // Thuis → winkel → thuis, metingen elke 5 s tijdens het rijden.
  List<TrackPoint> day() {
    final points = <TrackPoint>[];
    var t = DateTime(2026, 10, 9, 17);
    void stay(double lat, double lng, int minutes) {
      for (var i = 0; i < minutes * 4; i++) {
        points.add(TrackPoint(latitude: lat, longitude: lng, recordedAt: t, speedMps: 0));
        t = t.add(const Duration(seconds: 15));
      }
    }

    void drive(double fromLat, double fromLng, double toLat, double toLng) {
      for (var i = 1; i <= 24; i++) {
        final f = i / 24;
        points.add(
          TrackPoint(
            latitude: fromLat + (toLat - fromLat) * f,
            longitude: fromLng + (toLng - fromLng) * f,
            recordedAt: t,
            speedMps: 12,
          ),
        );
        t = t.add(const Duration(seconds: 5));
      }
    }

    stay(51.170, 4.395, 10);
    drive(51.170, 4.395, 51.180, 4.380);
    stay(51.180, 4.380, 20);
    drive(51.180, 4.380, 51.170, 4.395);
    stay(51.170, 4.395, 30);
    return points;
  }

  test('elke rit krijgt hetzelfde spoor als activityTrack, één keer berekend', () {
    final points = day();
    final entries = buildTimeline(points);
    final driving = DayDriving.build(entries, points);
    final expected = buildDayActivities(entries, points);

    expect(driving.activities, hasLength(expected.length));
    for (var i = 0; i < expected.length; i++) {
      final track = driving.trackAt(i);
      if (expected[i].kind == DrivingActivityKind.trip) {
        expect(track, isNotEmpty);
        expect(
          track.map((p) => p.recordedAt).toList(),
          activityTrack(expected[i], points).map((p) => p.recordedAt).toList(),
        );
      } else {
        expect(track, isEmpty);
      }
    }
    expect(driving.routes, hasLength(2));
  });

  test('een lege dag geeft geen activiteiten en geen routes', () {
    final driving = DayDriving.build(const [], const []);
    expect(driving.activities, isEmpty);
    expect(driving.routes, isEmpty);
  });

  test('de dag van de wintertijd telt 25 uur en mist zijn laatste uur niet', () {
    // De overgang in België valt op zondag 25 oktober 2026; het venster loopt
    // altijd van lokale middernacht tot de volgende lokale middernacht.
    final (start, end) = dayBounds(DateTime(2026, 10, 25, 14));
    expect(start, DateTime(2026, 10, 25));
    expect(end, DateTime(2026, 10, 26));
    expect(end.day, 26);
    expect(end.hour, 0);
  });
}
