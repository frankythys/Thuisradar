import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:thuisradar/features/driving/domain/driving_activity.dart';
import 'package:thuisradar/features/location/application/location_history_providers.dart';
import 'package:thuisradar/features/location/data/location_history_repository.dart';
import 'package:thuisradar/features/location/domain/timeline.dart';
import 'package:thuisradar/features/location/domain/track_point.dart';

/// Repository die de punten uit het geheugen teruggeeft in plaats van Supabase.
class _FakeHistory implements LocationHistoryRepository {
  _FakeHistory(this.points);

  final List<TrackPoint> points;

  @override
  Future<List<TrackPoint>> fetchDay(String userId, DateTime day) async => points;

  @override
  Future<List<TrackPoint>> fetchRange(String userId, DateTime start, DateTime end) async => points;
}

void main() {
  final day = DateTime(2026, 1, 2);

  // Elke meting een kilometer verder: zo wordt het een verplaatsing en geen
  // verblijf op één plek.
  TrackPoint point(int minutes) => TrackPoint(
    latitude: 51 + minutes / 1000,
    longitude: 3,
    recordedAt: day.add(Duration(minutes: minutes)),
  );

  // Een meting op dezelfde plek (werk), [minutes] na middernacht.
  TrackPoint stay(int minutes) =>
      TrackPoint(latitude: 51, longitude: 3, recordedAt: day.add(Duration(minutes: minutes)));

  Future<DayHistory> load(List<TrackPoint> points) async {
    final container = ProviderContainer(
      overrides: [locationHistoryRepositoryProvider.overrideWithValue(_FakeHistory(points))],
    );
    addTearDown(container.dispose);
    return container.read(dayHistoryProvider((userId: 'u1', day: day)).future);
  }

  test('een gat in de metingen levert geen rit van uren op het scherm', () async {
    // Even beweging, dan negen uur niets (toestel uit), dan weer even beweging.
    final history = await load([point(0), point(1), point(542), point(543)]);

    final activities = buildDayActivities(history.entries, history.points);
    // Geen enkele activiteit overbrugt het gat van negen uur.
    expect(activities, isNotEmpty);
    expect(activities.every((a) => a.duration < const Duration(hours: 1)), isTrue);
  });

  test('op het werk blijven over meetgaten heen is één verblijf', () async {
    // Aankomst op werk, dan grote gaten met maar losse metingen op dezelfde
    // plek (binnenshuis slechte GPS), en pas 's avonds weer dichte metingen.
    final history = await load([stay(40), stay(221), stay(224), stay(460), stay(540)]);

    final stays = buildDayActivities(
      history.entries,
      history.points,
    ).where((a) => a.kind == DrivingActivityKind.stay).toList();

    expect(stays, hasLength(1));
    expect(stays.single.duration, const Duration(minutes: 500));
  });

  test('een aaneengesloten rit blijft één verplaatsing met het routespoor', () async {
    final history = await load([point(0), point(2), point(4), point(6)]);

    expect(history.entries.where((e) => e.kind == TimelineKind.move), hasLength(1));
    expect(history.points, hasLength(4));
  });
}
