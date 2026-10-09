import 'member_on_map.dart';

/// Welke leden de kaart tekent. Is er iemand gekozen, dan alleen die persoon
/// (ook bij in- en uitzoomen), zodat de kaart niet druk wordt met de rest.
/// Staat de gekozen persoon niet (meer) in de lijst, dan iedereen.
List<MemberOnMap> membersToShow(List<MemberOnMap> members, String? selectedUserId) {
  if (selectedUserId == null) return members;
  final selected = [
    for (final member in members)
      if (member.member.userId == selectedUserId) member,
  ];
  return selected.isEmpty ? members : selected;
}
