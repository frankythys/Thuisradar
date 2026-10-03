import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/supabase/supabase_providers.dart';
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

/// Realtime ledenlijst: nieuwe gezinsleden verschijnen meteen.
final familyMembersProvider = StreamProvider.family<List<FamilyMember>, String>(
  (ref, familyId) => ref.watch(familyRepositoryProvider).watchMembers(familyId),
);
