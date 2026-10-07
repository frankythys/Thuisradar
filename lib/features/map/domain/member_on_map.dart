import 'dart:math' as math;

import '../../family/domain/family_member.dart';
import '../../location/domain/member_location.dart';
import '../../places/domain/place.dart';
import '../../places/domain/place_presence.dart';

/// Een gezinslid samen met zijn laatste locatie (kan nog ontbreken).
class MemberOnMap {
  const MemberOnMap({required this.member, this.location});

  final FamilyMember member;
  final MemberLocation? location;

  bool get hasLocation => location != null;
}

/// Wacht op de eigen locatie, ook als andere gezinsleden eerder geladen zijn.
MemberOnMap? startupMapMember(List<MemberOnMap> members, String? userId) {
  if (userId == null) return null;
  for (final member in members) {
    if (member.member.userId == userId && member.hasLocation) return member;
  }
  return null;
}

/// Koppelt leden aan locaties; volgorde van de leden blijft behouden.
List<MemberOnMap> combineMembers(List<FamilyMember> members, List<MemberLocation> locations) {
  final byUser = {for (final l in locations) l.userId: l};
  return [for (final m in members) MemberOnMap(member: m, location: byUser[m.userId])];
}

/// Is een lid binnen een opgeslagen plek, dan tonen we de stip op het midden
/// van die plek i.p.v. op de ruwe (binnenshuis vaak onnauwkeurige) GPS. Zo
/// staat "Thuis" altijd op het huis, zoals bij Life360. Puur en testbaar.
List<MemberOnMap> anchorMembersToPlaces(
  List<MemberOnMap> members,
  List<Place> places,
  List<PlacePresence> presence,
) {
  final placeById = {for (final p in places) p.id: p};

  // Per gebruiker de meest recente plek waar die nu binnen is.
  final anchorByUser = <String, Place>{};
  final sinceByUser = <String, DateTime?>{};
  for (final pres in presence) {
    if (!pres.isInside) continue;
    final place = placeById[pres.placeId];
    if (place == null) continue;
    final hasExisting = anchorByUser.containsKey(pres.userId);
    final existingSince = sinceByUser[pres.userId];
    final newer = !hasExisting || existingSince == null || (pres.since?.isAfter(existingSince) ?? false);
    if (newer) {
      anchorByUser[pres.userId] = place;
      sinceByUser[pres.userId] = pres.since;
    }
  }
  if (anchorByUser.isEmpty) return members;

  // Per plek: hoeveel geankerde leden met locatie staan erop?
  final totalByPlace = <String, int>{};
  for (final entry in members) {
    if (entry.location == null) continue;
    final place = anchorByUser[entry.member.userId];
    if (place != null) totalByPlace[place.id] = (totalByPlace[place.id] ?? 0) + 1;
  }

  final indexByPlace = <String, int>{};
  final result = <MemberOnMap>[];
  for (final entry in members) {
    final place = anchorByUser[entry.member.userId];
    final location = entry.location;
    if (place == null || location == null) {
      result.add(entry);
      continue;
    }
    final total = totalByPlace[place.id] ?? 1;
    final index = indexByPlace[place.id] ?? 0;
    indexByPlace[place.id] = index + 1;
    final point = _fannedPoint(place, index, total);
    result.add(
      MemberOnMap(
        member: entry.member,
        location: location.copyWith(latitude: point.lat, longitude: point.lng),
      ),
    );
  }
  return result;
}

/// Straal van de waaier waarin leden op dezelfde plek worden gezet, zodat ze bij
/// inzoomen uit elkaar gaan (zoals Life360) maar bij uitzoomen één groep blijven.
const _fanRadiusMeters = 18.0;

/// Eén lid staat exact op het midden; meerdere leden worden verdeeld over een
/// kleine cirkel rond het midden, zodat ze bij inzoomen zichtbaar scheiden.
({double lat, double lng}) _fannedPoint(Place place, int index, int total) {
  if (total <= 1) return (lat: place.latitude, lng: place.longitude);
  final angle = 2 * math.pi * index / total;
  final dxMeters = _fanRadiusMeters * math.cos(angle);
  final dyMeters = _fanRadiusMeters * math.sin(angle);
  final lat = place.latitude + dyMeters / 111320;
  final lng = place.longitude + dxMeters / (111320 * math.cos(place.latitude * math.pi / 180));
  return (lat: lat, lng: lng);
}
