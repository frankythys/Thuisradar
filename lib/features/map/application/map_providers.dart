import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;

import '../../../core/utils/clock.dart';
import '../../location/domain/trip_status.dart';
import '../data/road_network_source.dart';
import 'road_display_matcher.dart';

import '../../family/application/family_providers.dart';
import '../../location/application/location_providers.dart';
import '../../location/domain/member_location.dart';
import '../../places/application/places_providers.dart';
import '../../places/domain/place.dart';
import '../../places/domain/confirmed_presence.dart';
import '../../places/domain/place_presence.dart';
import '../domain/member_on_map.dart';
import '../domain/stationary_since.dart';

final membersOnMapProvider =
    Provider.family<AsyncValue<List<MemberOnMap>>, String>((ref, familyId) {
      final members = ref.watch(familyMembersProvider(familyId));
      final locations = ref.watch(familyLocationsProvider(familyId));

      return switch ((members, locations)) {
        (AsyncData(value: final m), AsyncData(value: final l)) => AsyncData(
          combineMembers(m, l),
        ),
        (AsyncError(:final error, :final stackTrace), _) ||
        (
          _,
          AsyncError(:final error, :final stackTrace),
        ) => AsyncError(error, stackTrace),
        _ => const AsyncLoading(),
      };
    });

final roadNetworkSourceProvider = Provider<RoadNetworkSource>((ref) {
  final client = http.Client();
  ref.onDispose(client.close);
  return RoadNetworkSource(client);
});

final roadMembersOnMapProvider = StreamProvider.autoDispose
    .family<List<MemberOnMap>, String>((ref, familyId) {
      final matcher = RoadDisplayMatcher(ref.watch(roadNetworkSourceProvider));
      final stream = StreamController<List<MemberOnMap>>();
      var generation = 0;
      ref.onDispose(() {
        matcher.dispose();
        unawaited(stream.close());
      });
      ref.listen(membersOnMapProvider(familyId), (_, next) {
        final members = next.value;
        if (members == null) return;
        final current = ++generation;
        final now = DateTime.now();
        stream.add(matcher.display(members, now));
        unawaited(
          matcher.update(members, now).then((_) {
            if (ref.mounted && current == generation) {
              stream.add(matcher.display(members, DateTime.now()));
            }
          }),
        );
      }, fireImmediately: true);
      return stream.stream;
    });

/// Zelfde leden, maar wie binnen een opgeslagen plek is, krijgt zijn stip op
/// het midden van die plek (Life360-stijl) i.p.v. op de ruwe GPS.
final anchoredMembersOnMapProvider =
    Provider.family<AsyncValue<List<MemberOnMap>>, String>((ref, familyId) {
      final members = ref.watch(membersOnMapProvider(familyId));
      final places =
          ref.watch(familyPlacesProvider(familyId)).value ?? const <Place>[];
      final locations =
          ref.watch(familyLocationsProvider(familyId)).value ??
          const <MemberLocation>[];
      // Een achterlopende aanwezigheid mag niemand die weg is op Thuis zetten.
      final presence = confirmedPresence(
        ref.watch(familyPresenceProvider(familyId)).value ??
            const <PlacePresence>[],
        places,
        locations,
      );
      final roads = ref.watch(roadMembersOnMapProvider(familyId)).value;
      final now = ref.watch(clockProvider).value ?? DateTime.now();
      return members.whenData((list) {
        // Oude async resultaten mogen nooit een nieuwere GPS-fix terugzetten.
        final roadById = {
          for (final member in roads ?? const <MemberOnMap>[])
            member.member.userId: member,
        };
        final displayed = [
          for (final member in list)
            if (TripStatus.at(member.location, now).state == TripState.moving &&
                roadById[member.member.userId]?.location?.updatedAt ==
                    member.location?.updatedAt)
              roadById[member.member.userId]!
            else
              member,
        ];
        // Een verouderde aanwezigheid op 'Thuis' mag een rijdende auto niet terug
        // naar het huis verplaatsen of over een gematchte wegpositie heen schrijven.
        final stationaryPresence = presence
            .where(
              (p) => !list.any(
                (m) =>
                    m.member.userId == p.userId &&
                    TripStatus.at(m.location, now).state == TripState.moving,
              ),
            )
            .toList();
        return anchorMembersToPlaces(displayed, places, stationaryPresence);
      });
    });

/// Onthoudt per familie de stop-ankers tussen herberekeningen door; opgeruimd
/// zodra de provider niet meer gebruikt wordt.
final _stationaryAnchors = <String, Map<String, StationaryAnchor>>{};

/// Per lid sinds wanneer het op dezelfde plek staat, zodat de kaart "hier sinds
/// 3 min" kan tonen — ook buiten een opgeslagen plek. Onthoudt de begintijd
/// zolang het lid niet meer dan [kStationaryMoveMeters] verschuift.
final stationarySinceProvider = Provider.family<Map<String, DateTime>, String>((
  ref,
  familyId,
) {
  final locations =
      ref.watch(familyLocationsProvider(familyId)).value ??
      const <MemberLocation>[];
  final next = updateStationaryAnchors(
    _stationaryAnchors[familyId] ?? const {},
    locations,
  );
  _stationaryAnchors[familyId] = next;
  ref.onDispose(() => _stationaryAnchors.remove(familyId));
  return {for (final entry in next.entries) entry.key: entry.value.since};
});
