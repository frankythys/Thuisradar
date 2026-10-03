import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/supabase/supabase_providers.dart';
import '../../auth/application/auth_providers.dart';
import '../data/events_repository.dart';
import '../domain/family_event.dart';

final eventsRepositoryProvider = Provider<EventsRepository>(
  (ref) => EventsRepository(ref.watch(supabaseClientProvider)),
);

final familyEventsProvider = StreamProvider.family<List<FamilyEvent>, String>(
  (ref, familyId) => ref.watch(eventsRepositoryProvider).watchEvents(familyId),
);

final lastSeenProvider = FutureProvider.family<DateTime?, String>((ref, familyId) {
  final userId = ref.watch(currentUserIdProvider);
  if (userId == null) return Future.value(null);
  return ref.watch(eventsRepositoryProvider).fetchLastSeen(userId, familyId);
});

/// Aantal ongelezen gebeurtenissen van ánderen (voor de tab-badge).
final unreadCountProvider = Provider.family<int, String>((ref, familyId) {
  final userId = ref.watch(currentUserIdProvider);
  final events = ref.watch(familyEventsProvider(familyId)).value ?? const [];
  final lastSeen = ref.watch(lastSeenProvider(familyId)).value;
  return events
      .where((e) => e.actorUserId != userId && (lastSeen == null || e.createdAt.isAfter(lastSeen)))
      .length;
});
