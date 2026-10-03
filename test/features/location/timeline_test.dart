import 'package:flutter_test/flutter_test.dart';
import 'package:thuisradar/features/location/domain/timeline.dart';
import 'package:thuisradar/features/location/domain/track_point.dart';

/// Basis in Gent; kleine graden-verschuivingen geven meters.
const _baseLat = 51.05;
const _baseLng = 3.72;

TrackPoint _p(double dLatM, double dLngM, DateTime at) {
  // ~111_320 m per graad breedte; lengte op 51° ~69_800 m per graad.
  return TrackPoint(latitude: _baseLat + dLatM / 111320, longitude: _baseLng + dLngM / 69800, recordedAt: at);
}

DateTime _t(int hour, int minute) => DateTime(2026, 1, 2, hour, minute);

void main() {
  test('lege invoer geeft een lege tijdlijn', () {
    expect(buildTimeline(const []), isEmpty);
  });

  test('lang op één plek blijven wordt één stop', () {
    final points = [_p(0, 0, _t(8, 0)), _p(10, 5, _t(8, 10)), _p(5, 10, _t(8, 20))];

    final timeline = buildTimeline(points);

    expect(timeline, hasLength(1));
    expect(timeline.single.kind, TimelineKind.stop);
    expect(timeline.single.duration, const Duration(minutes: 20));
  });

  test('stop, verplaatsing, stop levert drie blokken op', () {
    final points = [
      // Stop 1: thuis, 8:00-8:20
      _p(0, 0, _t(8, 0)),
      _p(5, 0, _t(8, 20)),
      // Onderweg: ver weg, kort
      _p(2000, 0, _t(8, 35)),
      // Stop 2: werk, 8:50-9:30
      _p(4000, 0, _t(8, 50)),
      _p(4010, 0, _t(9, 30)),
    ];

    final timeline = buildTimeline(points);

    expect(timeline.map((e) => e.kind).toList(), [TimelineKind.stop, TimelineKind.move, TimelineKind.stop]);

    final move = timeline[1];
    expect(move.distanceMeters, greaterThan(1500));
    expect(move.start, _t(8, 35));
    expect(move.end, _t(8, 50));
  });

  test('kort langskomen zonder te blijven is geen stop maar een move', () {
    final points = [_p(0, 0, _t(8, 0)), _p(1500, 0, _t(8, 2)), _p(3000, 0, _t(8, 5))];

    final timeline = buildTimeline(points);

    expect(timeline, hasLength(1));
    expect(timeline.single.kind, TimelineKind.move);
  });

  test('ongesorteerde invoer wordt chronologisch verwerkt', () {
    final points = [_p(4000, 0, _t(9, 30)), _p(0, 0, _t(8, 0)), _p(5, 0, _t(8, 20)), _p(4000, 0, _t(8, 50))];

    final timeline = buildTimeline(points);

    expect(timeline.first.kind, TimelineKind.stop);
    expect(timeline.first.start, _t(8, 0));
    expect(timeline.last.start.isAfter(timeline.first.start), isTrue);
  });

  test('placeName is standaard null zodat Fase D hem kan invullen', () {
    final points = [_p(0, 0, _t(8, 0)), _p(0, 0, _t(8, 30))];
    expect(buildTimeline(points).single.placeName, isNull);
  });
}
