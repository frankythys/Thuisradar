import 'package:flutter_test/flutter_test.dart';
import 'package:thuisradar/features/driving/domain/driving_activity.dart';
import 'package:thuisradar/features/location/domain/track_point.dart';

void main() {
  TrackPoint at(int second, double? speedMps) => TrackPoint(
    latitude: 51.2,
    longitude: 4.4,
    recordedAt: DateTime(2026, 10, 9, 16, 7, second),
    speedMps: speedMps,
  );

  test('topsnelheid is de hoogste gemeten snelheid in km/u', () {
    expect(topSpeedKmh([at(0, 5), at(5, 19.7), at(10, 12)]), 71);
  });

  test('onzinwaarden en ontbrekende snelheden tellen niet', () {
    expect(topSpeedKmh([at(0, null), at(5, -1), at(10, 120), at(15, 10)]), 36);
  });

  test('zonder bruikbare snelheid geen topsnelheid', () {
    expect(topSpeedKmh([at(0, null)]), isNull);
    expect(topSpeedKmh(const []), isNull);
  });
}
