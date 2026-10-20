import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/supabase/supabase_providers.dart';
import '../../../core/utils/resilient_stream.dart';
import '../../../core/utils/resync_signal.dart';
import '../../auth/application/auth_providers.dart';
import '../data/family_repository.dart';
import '../domain/family.dart';
import '../domain/family_member.dart';

final familyRepositoryProvider = Provider<FamilyRepository>(
  (ref) => FamilyRepository(ref.watch(supabaseClientProvider)),
);

/// De familie van de ingelogde gebruiker (null = nog geen familie).
/// Maakt eerst het profiel aan als dat nog niet bestaat.
final myFamilyProvider = FutureProvider<Family?>((ref) async {
  final userId = ref.watch(currentUserIdProvider);
  if (userId == null) return null;

  await ref.read(authRepositoryProvider).ensureProfile();
  return ref.read(familyRepositoryProvider).fetchMyFamily(userId);
});

/// Realtime ledenlijst: nieuwe gezinsleden verschijnen meteen. Herstelt
/// zichzelf als het realtime-kanaal wegvalt.
final familyMembersProvider = StreamProvider.family<List<FamilyMember>, String>((ref, familyId) {
  final repository = ref.watch(familyRepositoryProvider);
  return resilientStream(
    () => repository.watchMembers(familyId),
    resync: ref.watch(resyncSignalProvider).stream,
    onError: (error) => debugPrint('Ledenstroom (realtime) fout: $error'),
  );
});

/// De actuele uitnodigingscode van het gezin met haar vervaldatum. Niet
/// automatisch opnieuw proberen: het scherm valt terug op de bekende code.
final familyInviteProvider = FutureProvider.autoDispose.family<Family, String>(
  (ref, familyId) => ref.watch(familyRepositoryProvider).fetchInvite(familyId),
  retry: (_, _) => null,
);

/// Is de ingelogde gebruiker de beheerder van dit gezin?
final isFamilyOwnerProvider = Provider.autoDispose.family<bool, String>((ref, familyId) {
  final userId = ref.watch(currentUserIdProvider);
  final members = ref.watch(familyMembersProvider(familyId)).value ?? const <FamilyMember>[];
  return members.any((member) => member.userId == userId && member.isOwner);
});
