import 'package:flutter_test/flutter_test.dart';
import 'package:thuisradar/features/family/domain/family_member.dart';
import 'package:thuisradar/features/map/domain/map_focus.dart';
import 'package:thuisradar/features/map/domain/member_on_map.dart';

MemberOnMap _m(String id) => MemberOnMap(
  member: FamilyMember(userId: id, displayName: id, isOwner: false, colorIndex: 0),
  location: null,
);

void main() {
  final all = [_m('papa'), _m('mama'), _m('liam')];

  test('zonder keuze toont de kaart iedereen', () {
    expect(membersToShow(all, null), all);
  });

  test('met een gekozen persoon alleen die persoon', () {
    expect(membersToShow(all, 'mama').map((m) => m.member.userId), ['mama']);
  });

  test('onbekende keuze valt terug op iedereen', () {
    expect(membersToShow(all, 'emma'), all);
  });
}
