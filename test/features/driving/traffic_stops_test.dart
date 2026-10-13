import 'package:flutter_test/flutter_test.dart';
import 'package:thuisradar/features/driving/domain/driving_activity.dart';
import 'package:thuisradar/features/driving/domain/traffic_stops.dart';
import 'package:thuisradar/features/location/domain/timeline.dart';
import 'package:thuisradar/features/location/domain/track_point.dart';
import 'package:thuisradar/features/location/domain/travel_mode.dart';

/// Van het werk naar huis met veel file: één rit, met de wachttijd erbij.
void main() {
  final day = DateTime(2026, 10, 13, 16);

  /// [seconds] na vertrek, [km] noordwaarts van het werk.
  TrackPoint p(int seconds, double km, {double? speed, int? steps}) => TrackPoint(
    latitude: 51 + km * 0.009,
    longitude: 4,
    recordedAt: day.add(Duration(seconds: seconds)),
    speedMps: speed,
    steps: steps,
  );

  List<TrackPoint> stayAt(double km, int from, int to, {int every = 15, int? steps}) => [
    for (var s = from; s <= to; s += every) p(s, km, speed: 0, steps: steps),
  ];

  List<TrackPoint> drive(double fromKm, double toKm, int from, int to, {int every = 5, int? steps}) {
    final count = (to - from) ~/ every;
    return [
      for (var i = 1; i <= count; i++)
        p(from + i * every, fromKm + (toKm - fromKm) * i / count, speed: 13, steps: steps),
    ];
  }

  /// File: om de 15 s een meting, afwisselend stil en even aanschuiven, in
  /// totaal [meters] vooruit.
  List<TrackPoint> jam(double atKm, int from, int to, {double meters = 80, int? steps}) {
    final count = (to - from) ~/ 15;
    return [
      for (var i = 1; i <= count; i++)
        p(from + i * 15, atKm + meters / 1000 * i / count, speed: i.isEven ? 1.2 : 0, steps: steps),
    ];
  }

  /// Stapvoets: [meters] in [to] - [from] seconden, zonder stappen.
  List<TrackPoint> crawl(double fromKm, int from, int to, double meters) {
    final count = (to - from) ~/ 5;
    return [for (var i = 1; i <= count; i++) p(from + i * 5, fromKm + meters / 1000 * i / count, speed: 1.1)];
  }

  List<DrivingActivity> trips(List<TrackPoint> points) => buildDayActivities(
    buildTimeline(points),
    points,
  ).where((a) => a.kind == DrivingActivityKind.trip).toList();

  test('file met aanschuiven en stapvoets kruipen blijft één rit, met de wachttijd', () {
    final points = [
      ...stayAt(0, 0, 600),
      ...drive(0, 10, 600, 1400),
      // 7 minuten aanschuiven op 80 m: de tijdlijn ziet een "verblijf".
      ...jam(10, 1400, 1820),
      // 3 minuten stapvoets over 200 m: leek vroeger een wandeling.
      ...crawl(10.08, 1820, 2000, 200),
      ...drive(10.28, 20, 2000, 2800),
      ...jam(20, 2800, 3200, meters: 90),
      ...drive(20.09, 30, 3200, 4000),
      ...stayAt(30, 4015, 6000),
    ];

    final found = trips(points);

    expect(found, hasLength(1));
    final trip = found.single;
    expect(trip.mode, TravelMode.car);
    expect(trip.start, day.add(const Duration(seconds: 600)));
    expect(trip.distanceMeters, closeTo(30000, 800));
    // Ruim tien minuten stilstaan of stapvoets.
    expect(trip.waiting, isNotNull);
    expect(trip.waiting!.inMinutes, greaterThanOrEqualTo(10));
    expect(trip.waiting!, lessThan(trip.duration));
  });

  test('een echte tussenstop met uitstappen blijft twee ritten', () {
    final points = [
      ...stayAt(0, 0, 600, steps: 1000),
      ...drive(0, 10, 600, 1400, steps: 1000),
      // Tanken: 8 minuten stil en 60 stappen.
      ...[for (var s = 1415; s <= 1895; s += 15) p(s, 10, speed: 0, steps: 1000 + (s - 1415) ~/ 8)],
      ...drive(10, 20, 1895, 2700, steps: 1060),
      ...stayAt(20, 2715, 4000, steps: 1060),
    ];

    expect(trips(points), hasLength(2));
  });

  test('stilstaan op een eigen plaats blijft altijd een stop', () {
    final points = [
      ...stayAt(0, 0, 600),
      ...drive(0, 10, 600, 1400),
      ...jam(10, 1400, 1820),
      ...drive(10.08, 20, 1820, 2600),
      ...stayAt(20, 2615, 4000),
    ];
    final timeline = [
      for (final entry in buildTimeline(points))
        entry.kind == TimelineKind.stop && entry.start.isAfter(day.add(const Duration(seconds: 1300)))
            ? TimelineEntry(
                kind: entry.kind,
                start: entry.start,
                end: entry.end,
                latitude: entry.latitude,
                longitude: entry.longitude,
                placeName: entry.end.isBefore(day.add(const Duration(seconds: 2000))) ? 'Bakker' : 'Thuis',
              )
            : entry,
    ];
    final found = buildDayActivities(timeline, points).where((a) => a.kind == DrivingActivityKind.trip);

    expect(found, hasLength(2));
  });

  test('langer dan 20 minuten stil is een stop, ook met wat aanschuiven', () {
    final points = [
      ...stayAt(0, 0, 600),
      ...drive(0, 10, 600, 1400),
      ...jam(10, 1400, 2900),
      ...drive(10.08, 20, 2900, 3700),
      ...stayAt(20, 3715, 5000),
    ];

    expect(trips(points), hasLength(2));
  });

  test('wachttijd telt enkel stilstaan en stapvoets, geen meetgaten', () {
    final points = [
      ...drive(0, 2, 0, 150),
      ...stayAt(2, 165, 465),
      // Tunnel: 5 minuten geen meting.
      p(765, 2.5, speed: 13),
      ...drive(2.5, 4, 765, 900),
    ];

    final waiting = waitingTime(points, day, day.add(const Duration(seconds: 900)));

    expect(waiting.inSeconds, inInclusiveRange(290, 330));
  });

  test('een korte stop binnenshuis (GPS springt alle kanten op) blijft een stop', () {
    // Apotheek: 8 minuten, binnenshuis tot ±45 m ruis, geen stappenteller.
    final points = [
      ...stayAt(0, 0, 600),
      ...drive(0, 10, 600, 1400),
      for (var s = 1415; s <= 1895; s += 15)
        TrackPoint(
          latitude: 51 + 10 * 0.009 + ((s ~/ 15).isEven ? 0.0004 : -0.0004),
          longitude: 4 + ((s ~/ 30).isEven ? 0.0005 : -0.0005),
          recordedAt: day.add(Duration(seconds: s)),
          speedMps: 0,
        ),
      ...drive(10, 20, 1895, 2700),
      ...stayAt(20, 2715, 4000),
    ];

    expect(trips(points), hasLength(2));
  });
}
