import 'package:flutter_test/flutter_test.dart';
import 'package:thuisradar/features/driving/domain/driving_activity.dart';
import 'package:thuisradar/features/location/domain/timeline.dart';
import 'package:thuisradar/features/location/domain/track_point.dart';

/// Regressies uit de audit van 11 oktober 2026 (deel 2): de bestemming van een
/// rit, binnenshuis-ruis, sprongen na een meetgat, snelwegsnelheid en de
/// topsnelheid.
void main() {
  final day = DateTime(2026, 10, 12, 8);

  /// [seconds] na de start, [km] noordwaarts van het vertrekpunt.
  TrackPoint p(int seconds, double km, {double? speed}) => TrackPoint(
    latitude: 51 + km * 0.009,
    longitude: 4,
    recordedAt: day.add(Duration(seconds: seconds)),
    speedMps: speed,
  );

  List<TrackPoint> stayAt(double km, int fromSeconds, int toSeconds, {int every = 15}) => [
    for (var s = fromSeconds; s <= toSeconds; s += every) p(s, km, speed: 0),
  ];

  List<TrackPoint> drive(double fromKm, double toKm, int fromSeconds, int toSeconds, {int every = 5}) {
    final steps = (toSeconds - fromSeconds) ~/ every;
    return [
      for (var i = 1; i <= steps; i++)
        p(fromSeconds + i * every, fromKm + (toKm - fromKm) * i / steps, speed: 13),
    ];
  }

  List<DrivingActivity> trips(List<TrackPoint> points) => buildDayActivities(
    buildTimeline(points),
    points,
  ).where((a) => a.kind == DrivingActivityKind.trip).toList();

  test('een meetgat midden in een rit telt de kilometers niet dubbel en ritten overlappen niet', () {
    // Thuis, 3,9 km rijden, 6 min geen GPS, nog 3,9 km rijden, dan op het werk.
    final points = [
      ...stayAt(0, 0, 600),
      ...drive(0, 3.9, 600, 900),
      ...drive(5, 8.9, 1260, 1560),
      ...stayAt(8.9, 1575, 2400),
    ];

    final found = trips(points);
    final total = found.fold<double>(0, (sum, trip) => sum + trip.distanceMeters!);

    // Hooguit het overbrugde gat (1,1 km) erbij, nooit een tweede keer 3,9 km.
    expect(total, lessThan(9300));
    for (var i = 1; i < found.length; i++) {
      expect(found[i].start.isBefore(found[i - 1].end), isFalse, reason: 'ritten overlappen');
    }
  });

  test('een korte stop wordt de bestemming, niet de volgende stop na een tweede rit', () {
    // Thuis → school (7 min blijven) → bakker.
    final points = [
      ...stayAt(0, 0, 600),
      ...drive(0, 4, 600, 900),
      ...stayAt(4, 915, 1335),
      ...drive(4, 8, 1335, 1635),
      ...stayAt(8, 1650, 2400),
    ];

    final found = trips(points);

    expect(found, hasLength(2));
    expect(found.first.latitude, closeTo(51 + 4 * 0.009, 0.001));
    expect(found.first.distanceMeters, closeTo(4000, 300));
    expect(found.last.distanceMeters, closeTo(4000, 300));
  });

  test('losse binnenshuis-uitschieters maken van een avond thuis geen spookrit', () {
    // Een uur thuis met om de paar minuten één meting 120-160 m ernaast.
    final points = [
      for (var s = 0; s <= 3600; s += 15)
        s % 180 == 90 ? p(s, (s % 360 == 90 ? 0.13 : -0.15), speed: 0) : p(s, 0, speed: 0),
    ];

    expect(trips(points), isEmpty);
  });

  test('een sprong als eerste meting na een meetgat gooit de echte rit niet weg', () {
    final t0 = DateTime(2026, 10, 12, 9);
    TrackPoint at(int seconds, double km) => TrackPoint(
      latitude: 51 + km * 0.009,
      longitude: 4,
      recordedAt: t0.add(Duration(seconds: seconds)),
    );
    final points = [
      // Eerste fix na de tunnel ligt 1,5 km naast de weg.
      at(0, 1.5),
      for (var i = 1; i <= 12; i++) at(i * 5, i * 0.06),
    ];

    final kept = withoutSpikes(points);

    expect(kept.first.latitude, closeTo(51 + 0.06 * 0.009, 1e-9));
    expect(kept, hasLength(12));
  });

  test('snel snelwegrijden (180 km/u) blijft een aaneengesloten spoor', () {
    final t0 = DateTime(2026, 10, 12, 10);
    // 50 m/s, elke 5 s een meting.
    final points = [
      for (var i = 0; i <= 60; i++)
        TrackPoint(
          latitude: 51 + i * 0.25 * 0.009,
          longitude: 4,
          recordedAt: t0.add(Duration(seconds: i * 5)),
        ),
    ];

    expect(withoutSpikes(points), hasLength(points.length));
  });

  test('één losse Doppler-piek wordt geen topsnelheid', () {
    final t0 = DateTime(2026, 10, 12, 11);
    TrackPoint at(int seconds, double speed) => TrackPoint(
      latitude: 51,
      longitude: 4,
      recordedAt: t0.add(Duration(seconds: seconds)),
      speedMps: speed,
    );

    // 50 km/u, één meting van 216 km/u, weer 50 km/u.
    expect(topSpeedKmh([at(0, 14), at(5, 60), at(10, 14)]), 50);
    // Een echte versnelling met bevestigende buren telt wel.
    expect(topSpeedKmh([at(0, 25), at(5, 33), at(10, 30)]), 119);
  });
}
