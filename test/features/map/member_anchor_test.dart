import 'package:flutter_test/flutter_test.dart';
import 'package:thuisradar/features/family/domain/family_member.dart';
import 'package:thuisradar/features/location/domain/member_location.dart';
import 'package:thuisradar/features/map/domain/member_on_map.dart';
import 'package:thuisradar/features/places/domain/place.dart';
import 'package:thuisradar/features/places/domain/place_presence.dart';

void main() {
  const member = FamilyMember(userId: 'u1', displayName: 'Franky', isOwner: true, colorIndex: 0);
  final home = Place(
    id: 'home',
    familyId: 'fam',
    name: 'Thuis',
    latitude: 51.05,
    longitude: 3.72,
    radiusMeters: 100,
    icon: 'home',
  );

  MemberOnMap at(double lat, double lng) => MemberOnMap(
    member: member,
    location: MemberLocation(
      userId: 'u1',
      familyId: 'fam',
      latitude: lat,
      longitude: lng,
      updatedAt: DateTime(2026, 1, 2, 10),
    ),
  );

  test('binnen een plek staat de stip op het midden van die plek', () {
    final anchored = anchorMembersToPlaces([at(51.0503, 3.7206)], [home], [
      PlacePresence(userId: 'u1', placeId: 'home', isInside: true, since: DateTime(2026, 1, 2, 8)),
    ]);

    expect(anchored.single.location!.latitude, 51.05);
    expect(anchored.single.location!.longitude, 3.72);
  });

  test('buiten elke plek blijft de ruwe GPS-positie staan', () {
    final anchored = anchorMembersToPlaces([at(51.06, 3.73)], [home], [
      const PlacePresence(userId: 'u1', placeId: 'home', isInside: false),
    ]);

    expect(anchored.single.location!.latitude, 51.06);
    expect(anchored.single.location!.longitude, 3.73);
  });

  test('meerdere leden op dezelfde plek worden uitgewaaierd', () {
    const member2 = FamilyMember(userId: 'u2', displayName: 'Liam', isOwner: false, colorIndex: 1);
    final second = MemberOnMap(
      member: member2,
      location: MemberLocation(
        userId: 'u2',
        familyId: 'fam',
        latitude: 51.0509,
        longitude: 3.7215,
        updatedAt: DateTime(2026, 1, 2, 10),
      ),
    );

    final anchored = anchorMembersToPlaces([at(51.0503, 3.7206), second], [home], [
      PlacePresence(userId: 'u1', placeId: 'home', isInside: true, since: DateTime(2026, 1, 2, 8)),
      PlacePresence(userId: 'u2', placeId: 'home', isInside: true, since: DateTime(2026, 1, 2, 8)),
    ]);

    final a = anchored[0].location!;
    final b = anchored[1].location!;
    // Niet meer op exact hetzelfde punt: ze kunnen bij inzoomen scheiden.
    expect(a.latitude == b.latitude && a.longitude == b.longitude, isFalse);
    // Maar wel vlak bij het midden van de plek (binnen de straal).
    expect((a.latitude - 51.05).abs() < 0.001, isTrue);
    expect((b.latitude - 51.05).abs() < 0.001, isTrue);
  });

  test('zonder locatie verandert er niets', () {
    final anchored = anchorMembersToPlaces([const MemberOnMap(member: member)], [home], [
      const PlacePresence(userId: 'u1', placeId: 'home', isInside: true),
    ]);

    expect(anchored.single.location, isNull);
  });
}
