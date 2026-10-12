import '../../family/domain/family_member.dart';
import '../../location/domain/member_location.dart';
import '../../places/domain/place.dart';
import '../../places/domain/place_presence.dart';
import 'road_matching.dart';

/// Een gezinslid samen met zijn laatste locatie (kan nog ontbreken).
class MemberOnMap {
  const MemberOnMap({required this.member, this.location, this.roadPath});

  final FamilyMember member;
  final MemberLocation? location;

  /// Bekende wegvorm tussen de vorige en huidige fix, enkel voor weergave.
  final List<RoadPoint>? roadPath;

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

  final result = <MemberOnMap>[];
  for (final entry in members) {
    final place = anchorByUser[entry.member.userId];
    final location = entry.location;
    if (place == null || location == null) {
      result.add(entry);
      continue;
    }
    result.add(
      MemberOnMap(
        member: entry.member,
        location: location.copyWith(latitude: place.latitude, longitude: place.longitude),
      ),
    );
  }
  return result;
}
