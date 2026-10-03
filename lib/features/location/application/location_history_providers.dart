import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/supabase/supabase_providers.dart';
import '../data/location_history_repository.dart';
import '../domain/timeline.dart';

final locationHistoryRepositoryProvider = Provider<LocationHistoryRepository>(
  (ref) => LocationHistoryRepository(ref.watch(supabaseClientProvider)),
);

typedef HistoryQuery = ({String userId, DateTime day});

/// De tijdlijn (stops en verplaatsingen) van één gezinslid op één dag.
final timelineProvider = FutureProvider.family<List<TimelineEntry>, HistoryQuery>((ref, query) async {
  final points = await ref.watch(locationHistoryRepositoryProvider).fetchDay(query.userId, query.day);
  return buildTimeline(points);
});
