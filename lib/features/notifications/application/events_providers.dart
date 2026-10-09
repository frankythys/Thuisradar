import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/supabase/supabase_providers.dart';
import '../../auth/application/auth_providers.dart';
import '../../location/application/location_providers.dart';
import '../data/events_repository.dart';
import '../data/notifications_store.dart';
import '../domain/family_event.dart';
import '../domain/unread.dart';

final eventsRepositoryProvider = Provider<EventsRepository>(
  (ref) => EventsRepository(ref.watch(supabaseClientProvider)),
);

final notificationsStoreProvider = Provider<NotificationsStore>((ref) => NotificationsStore());

final familyEventsProvider = StreamProvider.family<List<FamilyEvent>, String>(
  (ref, familyId) => ref.watch(eventsRepositoryProvider).watchEvents(familyId),
);

final lastSeenProvider = FutureProvider.family<DateTime?, String>((ref, familyId) {
  final userId = ref.watch(currentUserIdProvider);
  if (userId == null) return Future.value(null);
  return ref.watch(eventsRepositoryProvider).fetchLastSeen(userId, familyId);
});

/// Batterijwaarschuwingen die al gezien zijn (lokaal op dit toestel).
final seenLowBatteryProvider = FutureProvider.family<Set<String>, String>(
  (ref, familyId) => ref.watch(notificationsStoreProvider).seenLowBattery(familyId),
);

/// Gezinsleden die nu een batterijwaarschuwing hebben.
final lowBatteryProvider = Provider.family<Set<String>, String>(
  (ref, familyId) => lowBatteryUserIds(ref.watch(familyLocationsProvider(familyId)).value ?? const []),
);

/// Aantal ongelezen meldingen voor de badge op het belletje.
final unreadCountProvider = Provider.family<int, String>((ref, familyId) {
  final lowBattery = ref.watch(lowBatteryProvider(familyId));
  return unreadNotifications(
    events: ref.watch(familyEventsProvider(familyId)).value ?? const [],
    userId: ref.watch(currentUserIdProvider),
    lastSeen: ref.watch(lastSeenProvider(familyId)).value,
    lowBattery: lowBattery,
    // Zolang de opgeslagen lijst laadt, geen batterijwaarschuwing tellen.
    seenLowBattery: ref.watch(seenLowBatteryProvider(familyId)).value ?? lowBattery,
  );
});

/// Markeert alle meldingen als gelezen: gebeurtenissen én batterijwaarschuwingen.
Future<void> markNotificationsSeen(WidgetRef ref, String familyId) async {
  final lowBattery = ref.read(lowBatteryProvider(familyId));
  await ref.read(notificationsStoreProvider).setSeenLowBattery(familyId, lowBattery);
  ref.invalidate(seenLowBatteryProvider(familyId));
  final userId = ref.read(currentUserIdProvider);
  if (userId == null) return;
  await ref.read(eventsRepositoryProvider).markSeen(userId, familyId);
  ref.invalidate(lastSeenProvider(familyId));
}
