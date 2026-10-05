import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
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

  Future<DayHistory> load(List<TrackPoint> points) async {
    final container = ProviderContainer(
      overrides: [locationHistoryRepositoryProvider.overrideWithValue(_FakeHistory(points))],
    );
    addTearDown(container.dispose);
    return container.read(dayHistoryProvider((userId: 'u1', day: day)).future);
  }

  test('een gat in de metingen is geen rit van uren', () async {
    // Kwartier thuis, dan negen uur niets (toestel uit), dan weer even beweging.
    final history = await load([point(0), point(1), point(542), point(543)]);

    final moves = history.entries.where((e) => e.kind == TimelineKind.move).toList();
    expect(moves, hasLength(2));
    for (final move in moves) {
      expect(move.duration, lessThanOrEqualTo(const Duration(minutes: 1)));
    }
  });

  test('een aaneengesloten rit blijft één verplaatsing met het routespoor', () async {
    final history = await load([point(0), point(2), point(4), point(6)]);

    expect(history.entries.where((e) => e.kind == TimelineKind.move), hasLength(1));
    expect(history.points, hasLength(4));
  });
}
