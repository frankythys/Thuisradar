import 'package:flutter_test/flutter_test.dart';
import 'package:thuisradar/features/driving/domain/driving_activity.dart';
import 'package:thuisradar/features/driving/domain/driving_report.dart';
import 'package:thuisradar/features/driving/domain/travel_legs.dart';
import 'package:thuisradar/features/location/domain/timeline.dart';
import 'package:thuisradar/features/location/domain/track_point.dart';
import 'package:thuisradar/features/location/domain/travel_mode.dart';

/// Zoals 12/10: met de auto naar de parking aan de werf, 3 minuten in de
/// wagen, dan te voet naar de barak. Metingen elke 5 s.
class _Day {
  final points = <TrackPoint>[];
  var t = DateTime(2026, 10, 12, 6, 20);
  var lat = 51.24;
  var steps = 5000;

  void move(int minutes, double kmh, {bool stepping = false}) {
    for (var i = 0; i < minutes * 12; i++) {
      lat += kmh / 3.6 * 5 / 111195;
      if (stepping) steps += 9;
      _add(kmh / 3.6);
    }
  }

  void sit(int minutes) {
    for (var i = 0; i < minutes * 12; i++) {
      _add(0);
    }
  }

  void _add(double mps) {
    t = t.add(const Duration(seconds: 5));
    points.add(TrackPoint(latitude: lat, longitude: 4.32, recordedAt: t, speedMps: mps, steps: steps));
  }
}

void main() {
  List<DrivingActivity> trips(List<TrackPoint> points) => buildDayActivities(
    buildTimeline(points),
    points,
  ).where((a) => a.kind == DrivingActivityKind.trip).toList();

  test('rijden, 3 min uitstappen, dan wandelen: een rit én een wandeling', () {
    final day = _Day()
      ..sit(10)
      ..move(12, 60)
      ..sit(3)
      ..move(6, 4.5, stepping: true)
      ..sit(20);
    final found = trips(day.points);
    expect(found.map((t) => t.mode), [TravelMode.car, TravelMode.walk]);
    final walk = found.last;
    expect(walk.distanceMeters, closeTo(450, 60));
    expect(walk.steps, inInclusiveRange(600, 660));
    // De wandeling begint pas als er gestapt wordt, niet bij het parkeren.
    expect(walk.start.isAfter(found.first.end), isTrue);

    final report = buildDrivingReport(day.points, DateTime(2026, 10, 12));
    expect(report.of(TravelMode.walk), hasLength(1));
    expect(report.of(TravelMode.car), hasLength(1));
  });

  test('wandelen naar de wagen en wegrijden: een wandeling én een rit', () {
    final day = _Day()
      ..sit(10)
      ..move(5, 5, stepping: true)
      ..sit(2)
      ..move(10, 70)
      ..sit(10);
    expect(trips(day.points).map((t) => t.mode), [TravelMode.walk, TravelMode.car]);
  });

  test('een korte wandeling (±150 m) telt met stappen als bewijs', () {
    final day = _Day()
      ..sit(10)
      ..move(2, 4.5, stepping: true)
      ..sit(10);
    final found = trips(day.points);
    expect(found.single.mode, TravelMode.walk);
    expect(found.single.distanceMeters, closeTo(150, 30));
  });

  test('rood licht of file zonder stappen splitst een rit niet', () {
    final day = _Day()
      ..sit(10)
      ..move(5, 50)
      ..sit(2)
      ..move(2, 4) // file aan wandeltempo, maar geen stappen
      ..move(5, 50)
      ..sit(10);
    expect(trips(day.points).map((t) => t.mode), [TravelMode.car]);
  });

  test('fietsen en dan te voet verder: een fietstocht én een wandeling', () {
    final day = _Day()
      ..sit(10)
      ..move(15, 18)
      ..sit(1)
      ..move(5, 5, stepping: true)
      ..sit(10);
    expect(trips(day.points).map((t) => t.mode), [TravelMode.bike, TravelMode.walk]);
  });

  test('één snelheidspiek tijdens het wandelen splitst niets', () {
    final day = _Day()..sit(2);
    day
      ..move(3, 5, stepping: true)
      ..move(0, 0);
    day.points.add(
      TrackPoint(
        latitude: day.lat,
        longitude: 4.32,
        recordedAt: day.t.add(const Duration(seconds: 5)),
        speedMps: 15,
        steps: day.steps,
      ),
    );
    day.t = day.t.add(const Duration(seconds: 5));
    day.move(3, 5, stepping: true);
    expect(splitByTravelMode(day.points), hasLength(1));
  });
}
