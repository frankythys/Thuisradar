import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../family/application/family_providers.dart';
import '../../location/application/location_providers.dart';
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
