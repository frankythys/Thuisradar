import 'package:flutter_test/flutter_test.dart';
import 'package:thuisradar/features/driving/domain/driving_activity.dart';
import 'package:thuisradar/features/driving/domain/driving_report.dart';
import 'package:thuisradar/features/driving/domain/travel_mode.dart';
import 'package:thuisradar/features/location/domain/timeline.dart';
import 'package:thuisradar/features/location/domain/track_point.dart';

void main() {
  group('classifyTravel', () {
    TravelMode classify(double kmh, {List<double?>? speeds, int minutes = 10}) => classifyTravel(
      meters: kmh / 3.6 * minutes * 60,
      duration: Duration(minutes: minutes),
      speedsMps: speeds ?? List.filled(20, kmh / 3.6),
    );

    test('wandeltempo is wandelen', () {
      expect(classify(4.5), TravelMode.walk);
      expect(classify(5, speeds: const []), TravelMode.walk);
    });

    test('fietstempo is fietsen, ook zonder GPS-snelheid', () {
      expect(classify(16), TravelMode.bike);
      expect(classify(15, speeds: const [null, null]), TravelMode.bike);
    });

    test('autosnelheid is rijden', () {
      expect(classify(50), TravelMode.car);
    });

    test('een file met af en toe 50 km/u blijft een rit', () {
      final speeds = [for (var i = 0; i < 20; i++) i % 4 == 0 ? 50 / 3.6 : 1.0];
      expect(classify(12, speeds: speeds), TravelMode.car);
    });

    test('één snelheidspiek maakt van een wandeling geen rit of fietstocht', () {
      final speeds = [for (var i = 0; i < 20; i++) i == 5 ? 30.0 : 1.3];
      expect(classify(4.7, speeds: speeds), TravelMode.walk);
    });

    test('een fietser die even bergaf gaat blijft een fietser', () {
      final speeds = [for (var i = 0; i < 30; i++) i < 3 ? 28 / 3.6 : 17 / 3.6];
      expect(classify(17, speeds: speeds), TravelMode.bike);
    });

    test('onzinwaarden tellen niet', () {
      expect(classify(4, speeds: const [double.nan, -3, 99, 99]), TravelMode.walk);
    });

    test('gemiddelde snelheid in km/u', () {
      expect(averageSpeedKmh(1000, const Duration(minutes: 12)), closeTo(5, .01));
      expect(averageSpeedKmh(null, const Duration(minutes: 12)), isNull);
      expect(averageSpeedKmh(1000, Duration.zero), isNull);
    });

    test('Nederlandse telwoorden', () {
      expect(TravelMode.walk.count(1), '1 wandeling');
      expect(TravelMode.bike.count(2), '2 fietstochten');
      expect(TravelMode.car.count(3), '3 ritten');
    });
  });

  // Thuis → wandeling van ±1,2 km aan 5 km/u (meting elke 5 s) → thuis.
  List<TrackPoint> walkDay({double kmh = 5, double meters = 1200}) {
    final points = <TrackPoint>[];
    var t = DateTime(2026, 10, 7, 14);
    void stay(double lat, int minutes) {
      for (var i = 0; i < minutes * 4; i++) {
        points.add(TrackPoint(latitude: lat, longitude: 4.4, recordedAt: t, speedMps: 0));
        t = t.add(const Duration(seconds: 15));
      }
    }

    stay(51.17, 10);
    final mps = kmh / 3.6;
    final steps = (meters / mps / 5).round();
    for (var i = 1; i <= steps; i++) {
      t = t.add(const Duration(seconds: 5));
      points.add(
        TrackPoint(
          latitude: 51.17 + meters / 111195 * i / steps,
          longitude: 4.4,
          recordedAt: t,
          speedMps: mps,
        ),
      );
    }
    stay(51.17 + meters / 111195, 10);
    return points;
  }

  test('een wandeling verschijnt in de dag als wandeling met afstand en tempo', () {
    final points = walkDay();
    final trips = buildDayActivities(
      buildTimeline(points),
      points,
    ).where((a) => a.kind == DrivingActivityKind.trip).toList();
    expect(trips, hasLength(1));
    expect(trips.single.mode, TravelMode.walk);
    expect(trips.single.distanceMeters, closeTo(1200, 60));
    expect(trips.single.averageKmh, closeTo(5, .5));
  });

  test('een fietstocht verschijnt als fietstocht', () {
    final points = walkDay(kmh: 18, meters: 4000);
    final trips = buildDayActivities(
      buildTimeline(points),
      points,
    ).where((a) => a.kind == DrivingActivityKind.trip);
    expect(trips.single.mode, TravelMode.bike);
  });

  test('een heel kort stukje te voet is geen wandeling', () {
    final points = walkDay(meters: 200);
    final trips = buildDayActivities(
      buildTimeline(points),
      points,
    ).where((a) => a.kind == DrivingActivityKind.trip);
    expect(trips, isEmpty);
  });

  test('het weekrapport telt wandelingen apart van de ritten', () {
    final report = buildDrivingReport(walkDay(), DateTime(2026, 10, 5));
    expect(report.trips, isEmpty);
    expect(report.of(TravelMode.walk), hasLength(1));
    expect(report.kilometersOf(TravelMode.walk), closeTo(1.2, .06));
    expect(report.durationOf(TravelMode.walk).inMinutes, inInclusiveRange(13, 16));
    expect(report.topSpeed, isNull);
  });
}
