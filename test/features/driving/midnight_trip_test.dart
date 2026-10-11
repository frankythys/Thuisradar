import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:thuisradar/features/driving/application/driving_providers.dart';
import 'package:thuisradar/features/driving/domain/day_driving.dart';
import 'package:thuisradar/features/driving/domain/driving_activity.dart';
import 'package:thuisradar/features/location/application/location_history_providers.dart';
import 'package:thuisradar/features/location/data/location_history_repository.dart';
import 'package:thuisradar/features/location/domain/timeline.dart';
import 'package:thuisradar/features/location/domain/track_point.dart';
import 'package:thuisradar/features/places/application/places_providers.dart';
import 'package:thuisradar/features/places/domain/place.dart';

/// Thuis tot 23:45, rijden 23:50 → 00:20 (±15 km), dan op bestemming.
List<TrackPoint> _night() {
  final points = <TrackPoint>[];
  final start = DateTime(2026, 10, 4, 23, 30);
  for (var s = 0; s <= 20 * 60; s += 15) {
    points.add(
      TrackPoint(latitude: 51, longitude: 4, recordedAt: start.add(Duration(seconds: s)), speedMps: 0),
    );
  }
  final departure = DateTime(2026, 10, 4, 23, 50);
  for (var s = 5; s <= 30 * 60; s += 5) {
    points.add(
      TrackPoint(
        latitude: 51 + 0.135 * s / 1800,
        longitude: 4,
        recordedAt: departure.add(Duration(seconds: s)),
        speedMps: 8.3,
      ),
    );
  }
  final arrival = DateTime(2026, 10, 5, 0, 20, 15);
  for (var s = 0; s <= 40 * 60; s += 15) {
    points.add(
      TrackPoint(latitude: 51.135, longitude: 4, recordedAt: arrival.add(Duration(seconds: s)), speedMps: 0),
    );
  }
  return points;
}

final _day1 = DateTime(2026, 10, 4);
final _day2 = DateTime(2026, 10, 5);

void main() {
  test('een rit over middernacht staat heel op zijn vertrekdag', () {
    final points = _night();
    final driving = DayDriving.build(buildTimeline(points), points, from: _day1, to: _day2);
    final trips = driving.activities.where((a) => a.kind == DrivingActivityKind.trip).toList();

    expect(trips, hasLength(1));
    expect(trips.single.start.isBefore(_day2), isTrue);
    expect(trips.single.end.isAfter(_day2), isTrue, reason: 'de rit loopt door na middernacht');
    expect(trips.single.distanceMeters, closeTo(15000, 600));
    // Het spoor op de kaart loopt ook door tot de bestemming.
    expect(driving.trackAt(driving.activities.indexOf(trips.single)).last.latitude, closeTo(51.135, 0.001));
  });

  test('de volgende dag toont die rit niet nog eens, wel het verblijf vanaf de aankomst', () {
    final points = _night();
    final driving = DayDriving.build(buildTimeline(points), points, from: _day2, to: DateTime(2026, 10, 6));

    expect(driving.activities.where((a) => a.kind == DrivingActivityKind.trip), isEmpty);
    final stay = driving.activities.single;
    expect(stay.kind, DrivingActivityKind.stay);
    expect(stay.start.isBefore(DateTime(2026, 10, 5, 0, 21)), isTrue);
    expect(stay.start.isAfter(_day2), isTrue);
  });

  test('een verblijf over middernacht wordt op de dag afgeknipt', () {
    final points = _night();
    final driving = DayDriving.build(buildTimeline(points), points, from: _day1, to: _day2);
    final stays = driving.activities.where((a) => a.kind == DrivingActivityKind.stay);

    expect(stays.every((s) => !s.start.isBefore(_day1) && !s.end.isAfter(_day2)), isTrue);
  });

  test('de provider haalt de marge rond de dag erbij en houdt de rit heel', () async {
    final all = _night();
    final container = ProviderContainer(
      overrides: [
        locationHistoryRepositoryProvider.overrideWithValue(_Repo(all)),
        familyPlacesProvider.overrideWith((ref, id) => Stream.value(const <Place>[])),
      ],
    );
    addTearDown(container.dispose);
    final query = (familyId: 'fam', userId: 'u1', day: _day1);
    final subscription = container.listen(dayDrivingProvider(query), (_, _) {});
    addTearDown(subscription.close);

    await container.read(dayHistoryProvider((userId: 'u1', day: _day1)).future);
    await container.read(dayMarginsProvider((userId: 'u1', day: _day1)).future);
    final driving = container.read(dayDrivingProvider(query)).value!;
    final trip = driving.activities.singleWhere((a) => a.kind == DrivingActivityKind.trip);

    expect(trip.distanceMeters, closeTo(15000, 600));
    expect(trip.end.isAfter(_day2), isTrue);
  });
}

/// Geeft de punten binnen het gevraagde venster terug, zoals Supabase.
class _Repo implements LocationHistoryRepository {
  _Repo(this.points);

  final List<TrackPoint> points;

  @override
  Duration get pageTimeout => const Duration(seconds: 10);

  @override
  Future<List<TrackPoint>> fetchDay(String userId, DateTime day) {
    final (start, end) = dayBounds(day);
    return fetchRange(userId, start, end);
  }

  @override
  Future<List<TrackPoint>> fetchRange(String userId, DateTime start, DateTime end) async => [
    for (final point in points)
      if (!point.recordedAt.isBefore(start) && point.recordedAt.isBefore(end)) point,
  ];
}
