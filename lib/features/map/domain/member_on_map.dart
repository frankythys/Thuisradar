import '../../family/domain/family_member.dart';
import '../../location/domain/member_location.dart';

/// Een gezinslid samen met zijn laatste locatie (kan nog ontbreken).
class MemberOnMap {
  const MemberOnMap({required this.member, this.location});

  final FamilyMember member;
  final MemberLocation? location;

  bool get hasLocation => location != null;
}

/// Koppelt leden aan locaties; volgorde van de leden blijft behouden.
List<MemberOnMap> combineMembers(List<FamilyMember> members, List<MemberLocation> locations) {
  final byUser = {for (final l in locations) l.userId: l};
  return [for (final m in members) MemberOnMap(member: m, location: byUser[m.userId])];
}
