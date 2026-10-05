import 'package:flutter_test/flutter_test.dart';
import 'package:thuisradar/features/driving/domain/driving_report.dart';
import 'package:thuisradar/features/location/domain/track_point.dart';

final week = DateTime(2026, 10, 5);
TrackPoint point(int minute, double latitude, {double? speed = 15}) => TrackPoint(
  latitude: latitude,
  longitude: 3.7,
  recordedAt: DateTime(2026, 10, 5, 9, minute),
  speedMps: speed,
);

void main() {
  test('week begint op maandag, inclusief jaargrens', () {
    expect(drivingWeekStart(DateTime(2027, 1, 3)), DateTime(2026, 12, 28));
    expect(drivingWeekEnd(DateTime(2026, 12, 28)), DateTime(2027, 1, 4));
  });
  test('geen geschiedenis is niet hetzelfde als nul herkende ritten', () {
    expect(buildDrivingReport([], week).hasHistory, isFalse);
    final report = buildDrivingReport([point(0, 51), point(1, 51)], week);
    expect(report.hasHistory, isTrue);
    expect(report.trips, isEmpty);
    expect(report.topSpeed, isNull);
  });
  test('rit berekent afstand en hoogste snelheid, ongeacht invoervolgorde', () {
    final report = buildDrivingReport([point(2, 51.02, speed: 20), point(0, 51), point(1, 51.01)], week);
    expect(report.trips, hasLength(1));
    expect(report.kilometers, closeTo(2.224, .01));
    expect(report.topSpeed, 72);
  });
  test('wandelen en ontbrekende snelheid tellen niet als autorit', () {
    expect(buildDrivingReport([point(0, 51, speed: 1), point(1, 51.001, speed: 1)], week).trips, isEmpty);
    expect(
      buildDrivingReport([point(0, 51, speed: null), point(1, 51.01, speed: null)], week).trips,
      isEmpty,
    );
  });
  test('lange gaten verbinden geen ritten of afstanden', () {
    final report = buildDrivingReport([point(0, 51), point(1, 51.01), point(30, 52), point(31, 52.01)], week);
    expect(report.trips, hasLength(2));
    expect(report.kilometers, closeTo(2.224, .01));
  });
  test('punten buiten geselecteerde week tellen niet mee', () {
    expect(buildDrivingReport([point(0, 51), point(1, 51.01)], DateTime(2026, 9, 28)).hasHistory, isFalse);
  });
  test('onmogelijke GPS-sprongen en enkele snelheidspiek tellen niet', () {
    expect(buildDrivingReport([point(0, 51), point(1, 53)], week).trips, isEmpty);
    expect(buildDrivingReport([point(0, 51, speed: 1), point(1, 51.001, speed: 30)], week).trips, isEmpty);
  });
}
