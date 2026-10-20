import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../auth/application/auth_providers.dart';
import '../../family/application/family_providers.dart';
import '../../family/domain/family_member.dart';
import '../../geofencing/application/geofencing_providers.dart';
import '../../location/application/location_providers.dart';

/// Stopt het delen zodra de ingelogde gebruiker geen lid meer is van het gezin
/// (de beheerder verwijderde hem). Zonder deze wacht bleven GPS en geofencing
/// draaien tot de app herstartte, terwijl elke upload door RLS geweigerd werd.
/// Daarna wordt het gezin opnieuw opgehaald, zodat FamilyGate het
/// gezinskeuzescherm toont.
final membershipGuardProvider = Provider.autoDispose.family<void, String>((ref, familyId) {
  ref.listen<AsyncValue<List<FamilyMember>>>(familyMembersProvider(familyId), (_, next) {
    final myId = ref.read(currentUserIdProvider);
    final members = next.value;
    if (myId == null || members == null || members.any((member) => member.userId == myId)) return;
    ref.read(locationTrackerProvider.notifier).stop(reason: 'geen lid meer van het gezin');
    unawaited(ref.read(geofenceSyncProvider.notifier).stop());
    ref.invalidate(myFamilyProvider);
  });
});
