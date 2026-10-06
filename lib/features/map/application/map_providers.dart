import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../family/application/family_providers.dart';
import '../../location/application/location_providers.dart';
import '../../places/application/places_providers.dart';
import '../../places/domain/place.dart';
import '../../places/domain/place_presence.dart';
import '../domain/member_on_map.dart';

final membersOnMapProvider = Provider.family<AsyncValue<List<MemberOnMap>>, String>((ref, familyId) {
  final members = ref.watch(familyMembersProvider(familyId));
  final locations = ref.watch(familyLocationsProvider(familyId));

  return switch ((members, locations)) {
    (AsyncData(value: final m), AsyncData(value: final l)) => AsyncData(combineMembers(m, l)),
    (AsyncError(:final error, :final stackTrace), _) ||
    (_, AsyncError(:final error, :final stackTrace)) => AsyncError(error, stackTrace),
    _ => const AsyncLoading(),
  };
});

/// Zelfde leden, maar wie binnen een opgeslagen plek is, krijgt zijn stip op
/// het midden van die plek (Life360-stijl) i.p.v. op de ruwe GPS.
final anchoredMembersOnMapProvider = Provider.family<AsyncValue<List<MemberOnMap>>, String>((ref, familyId) {
  final members = ref.watch(membersOnMapProvider(familyId));
  final places = ref.watch(familyPlacesProvider(familyId)).value ?? const <Place>[];
  final presence = ref.watch(familyPresenceProvider(familyId)).value ?? const <PlacePresence>[];
  return members.whenData((list) => anchorMembersToPlaces(list, places, presence));
});
