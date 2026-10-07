import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../family/application/family_providers.dart';
import '../../location/application/location_providers.dart';
import '../../location/domain/member_location.dart';
import '../../places/application/places_providers.dart';
import '../../places/domain/place.dart';
import '../../places/domain/place_presence.dart';
import '../domain/member_on_map.dart';
import '../domain/stationary_since.dart';

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

/// Onthoudt per familie de stop-ankers tussen herberekeningen door; opgeruimd
/// zodra de provider niet meer gebruikt wordt.
final _stationaryAnchors = <String, Map<String, StationaryAnchor>>{};

/// Per lid sinds wanneer het op dezelfde plek staat, zodat de kaart "hier sinds
/// 3 min" kan tonen — ook buiten een opgeslagen plek. Onthoudt de begintijd
/// zolang het lid niet meer dan [kStationaryMoveMeters] verschuift.
final stationarySinceProvider = Provider.family<Map<String, DateTime>, String>((ref, familyId) {
  final locations = ref.watch(familyLocationsProvider(familyId)).value ?? const <MemberLocation>[];
  final next = updateStationaryAnchors(_stationaryAnchors[familyId] ?? const {}, locations);
  _stationaryAnchors[familyId] = next;
  ref.onDispose(() => _stationaryAnchors.remove(familyId));
  return {for (final entry in next.entries) entry.key: entry.value.since};
});
