import 'package:flutter_test/flutter_test.dart';
import 'package:thuisradar/features/location/domain/track_point.dart';
import 'package:thuisradar/features/location/domain/track_segments.dart';

void main() {
  final day = DateTime(2026, 1, 2);

  TrackPoint point(int minutes) => TrackPoint(
    latitude: 51,
    longitude: 3,
    recordedAt: day.add(Duration(minutes: minutes)),
  );

  test('een gat groter dan vijf minuten begint een nieuw stuk', () {
    final segments = splitTrackGaps([
      point(0),
      point(1),
      point(2),
      point(40),
      point(41),
    ]);

    expect(segments, hasLength(2));
    expect(segments.first, hasLength(3));
    expect(segments.last, hasLength(2));
  });

  test('vijf minuten tussen twee metingen is nog geen gat', () {
    expect(splitTrackGaps([point(0), point(5), point(10)]), hasLength(1));
  });

  test('losse punten leveren geen route op', () {
    expect(splitTrackGaps([point(0), point(30)]), isEmpty);
  });

  test('een korte reeks binnen de grens blijft één stuk', () {
    final segments = splitTrackGaps([point(0), point(2), point(4), point(6)]);

    expect(segments, hasLength(1));
    expect(segments.single, hasLength(4));
  });

  test('routekaart verbindt meetgaten van minuten niet', () {
    expect(
      routeMapSegments([point(0), point(1), point(4), point(5)]),
      hasLength(2),
    );
  });

  test('routekaart onderbreekt onmogelijke sprong en sorteert het spoor', () {
    TrackPoint at(double lat, int second) => TrackPoint(
      latitude: lat,
      longitude: 3,
      recordedAt: day.add(Duration(seconds: second)),
    );
    final input = [at(51.0001, 5), at(51, 0), at(52, 10), at(52.0001, 15)];
    final segments = routeMapSegments(input);
    expect(segments, hasLength(2));
    expect(segments.first.first.recordedAt, day);
    expect(segments.first.last.latitude, 51.0001);
    expect(input.first.recordedAt, day.add(const Duration(seconds: 5)));
  });

  test('losse ritmetingen blijven zichtbaar zonder verbindingslijn', () {
    final segments = routeMapSegments([point(0), point(4), point(8)]);
    expect(segments, hasLength(3));
    expect(segments.every((segment) => segment.length == 1), isTrue);
  });
}
