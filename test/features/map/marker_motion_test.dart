import 'package:flutter_test/flutter_test.dart';
import 'package:thuisradar/features/map/domain/marker_motion.dart';

void main() {
  final start = DateTime(2026, 10, 2, 18, 0);

  test('duur blijft binnen de grenzen', () {
    expect(markerMotionDuration(start, start), markerMotionMin);
    expect(markerMotionDuration(start, start.add(const Duration(seconds: 5))), markerMotionMax);
  });

  test('duur volgt het gat tussen twee ontvangen punten', () {
    expect(
      markerMotionDuration(start, start.add(const Duration(milliseconds: 1200))),
      const Duration(milliseconds: 1200),
    );
  });

  test('interpolatie beweegt enkel tussen de twee punten', () {
    const from = (lat: 50.0, lng: 4.0);
    const to = (lat: 51.0, lng: 5.0);

    expect(lerpCoordinate(from, to, 0), from);
    expect(lerpCoordinate(from, to, 1), to);
    expect(lerpCoordinate(from, to, 0.5), (lat: 50.5, lng: 4.5));
  });
}
