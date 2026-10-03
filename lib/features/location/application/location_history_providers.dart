import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/supabase/supabase_providers.dart';
import '../data/location_history_repository.dart';
import '../domain/timeline.dart';

final locationHistoryRepositoryProvider = Provider<LocationHistoryRepository>(
  (ref) => LocationHistoryRepository(ref.watch(supabaseClientProvider)),
);

typedef HistoryQuery = ({String userId, DateTime day});

/// Hoe lang we maximaal op de geschiedenis wachten voor we een fout tonen.
const _historyTimeout = Duration(seconds: 10);

/// De tijdlijn (stops en verplaatsingen) van één gezinslid op één dag.
/// Faalt of time-out → AsyncError (het scherm toont dan een foutmelding met
/// "Opnieuw proberen"); nooit oneindig laden.
final timelineProvider = FutureProvider.family<List<TimelineEntry>, HistoryQuery>((ref, query) async {
  final repository = ref.watch(locationHistoryRepositoryProvider);
  try {
    final points = await repository.fetchDay(query.userId, query.day).timeout(_historyTimeout);
    return buildTimeline(points);
  } on Object catch (error, stackTrace) {
    debugPrint('Geschiedenis laden mislukt voor ${query.userId} op ${query.day}: $error');
    debugPrintStack(stackTrace: stackTrace);
    rethrow;
  }
});
