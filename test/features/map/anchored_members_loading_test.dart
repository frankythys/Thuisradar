import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:thuisradar/core/utils/clock.dart';
import 'package:thuisradar/features/family/domain/family_member.dart';
import 'package:thuisradar/features/location/application/location_providers.dart';
import 'package:thuisradar/features/location/domain/member_location.dart';
import 'package:thuisradar/features/map/application/map_providers.dart';
import 'package:thuisradar/features/map/domain/member_on_map.dart';
import 'package:thuisradar/features/places/application/places_providers.dart';
import 'package:thuisradar/features/places/domain/place.dart';
import 'package:thuisradar/features/places/domain/place_presence.dart';

void main() {
  test('eerste kaartbeeld wacht op huis en aanwezigheid, daarna blijft de kaart bij verversen', () async {
    final places = StreamController<List<Place>>();
    final presence = StreamController<List<PlacePresence>>();
    final now = DateTime(2026, 10, 11, 12);
    final location = MemberLocation(
      userId: 'u',
      familyId: 'f',
      latitude: 51.0001,
      longitude: 3,
      speedMps: 0,
      updatedAt: now,
    );
    final members = [
      MemberOnMap(
        member: const FamilyMember(userId: 'u', displayName: 'Franky', isOwner: true, colorIndex: 0),
        location: location,
      ),
    ];
    final container = ProviderContainer(
      overrides: [
        membersOnMapProvider('f').overrideWithValue(AsyncData(members)),
        familyLocationsProvider('f').overrideWith((ref) => Stream.value([location])),
        familyPlacesProvider('f').overrideWith((ref) => places.stream),
        familyPresenceProvider('f').overrideWith((ref) => presence.stream),
        roadMembersOnMapProvider('f').overrideWith((ref) => Stream.value(members)),
        clockProvider.overrideWith((ref) => Stream.value(now)),
      ],
    );
    addTearDown(() async {
      container.dispose();
      await places.close();
      await presence.close();
    });
    final provider = anchoredMembersOnMapProvider('f');
    container.listen(provider, (_, _) {});
    await Future<void>.delayed(Duration.zero);
    expect(container.read(provider).isLoading, isTrue);
    places.add(const [
      Place(
        id: 'home',
        familyId: 'f',
        name: 'Thuis',
        latitude: 51,
        longitude: 3,
        radiusMeters: 100,
        icon: 'home',
      ),
    ]);
    await Future<void>.delayed(Duration.zero);
    expect(container.read(provider).isLoading, isTrue);
    presence.add(const [PlacePresence(userId: 'u', placeId: 'home', isInside: true)]);
    await Future<void>.delayed(Duration.zero);
    expect(container.read(provider).requireValue.single.location!.latitude, 51);
    container.invalidate(familyPlacesProvider('f'));
    expect(container.read(provider).hasValue, isTrue);
  });
}
