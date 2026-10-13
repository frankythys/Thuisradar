import 'package:flutter_test/flutter_test.dart';
import 'package:thuisradar/features/family/domain/family_member.dart';
import 'package:thuisradar/features/location/domain/member_location.dart';
import 'package:thuisradar/features/map/domain/member_on_map.dart';
import 'package:thuisradar/features/map/presentation/widgets/group_pin.dart';

void main() {
  final now = DateTime(2026, 10, 13, 12);
  MemberOnMap member(String id, {int colorIndex = 0}) => MemberOnMap(
    member: FamilyMember(userId: id, displayName: id, isOwner: false, colorIndex: colorIndex),
    location: MemberLocation(userId: id, familyId: 'f', latitude: 51, longitude: 3, updatedAt: now),
  );

  test('groepspin: zelfde inhoud geeft dezelfde sleutel, echte wijziging een andere', () {
    String key(List<MemberOnMap> members, {DateTime? at, String? selected}) =>
        GroupPin(members: members, now: at ?? now, selectedUserId: selected).imageKey;
    final family = [member('Franky'), member('Liam')];
    expect(key(family), key([member('Franky'), member('Liam')]));
    expect(key(family, selected: 'Liam'), isNot(key(family)));
    expect(key([member('Franky'), member('Liam', colorIndex: 2)]), isNot(key(family)));
    expect(key([...family, member('Mama')]), isNot(key(family)));
    // De tijd in de ballon verspringt: dan pas opnieuw tekenen.
    expect(key(family, at: now.add(const Duration(minutes: 5))), isNot(key(family)));
  });
}
