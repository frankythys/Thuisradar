import 'package:flutter_test/flutter_test.dart';
import 'package:thuisradar/features/family/domain/family_member.dart';
import 'package:thuisradar/features/location/domain/member_location.dart';
import 'package:thuisradar/features/map/domain/member_on_map.dart';

FamilyMember _member(String id, int index) =>
    FamilyMember(userId: id, displayName: id, isOwner: index == 0, colorIndex: index);

MemberLocation _location(String userId) => MemberLocation(
  userId: userId,
  familyId: 'f1',
  latitude: 50,
  longitude: 4,
  updatedAt: DateTime(2026, 10, 2),
);

void main() {
  test('start op de ingelogde persoon, niet het eerste gezinslid', () {
    final members = combineMembers(
      [_member('papa', 0), _member('mama', 1)],
      [_location('papa'), _location('mama')],
    );
    expect(startupMapMember(members, 'mama')?.member.userId, 'mama');
  });

  test('wacht op eigen locatie als alleen andere leden geladen zijn', () {
    final members = combineMembers([_member('papa', 0), _member('mama', 1)], [_location('papa')]);
    expect(startupMapMember(members, 'mama'), isNull);
    expect(startupMapMember(members, null), isNull);
    final updated = combineMembers(
      [_member('papa', 0), _member('mama', 1)],
      [_location('papa'), _location('mama')],
    );
    expect(startupMapMember(updated, 'mama')?.location, isNotNull);
  });
  test('koppelt locaties aan leden en behoudt de volgorde van de leden', () {
    final result = combineMembers(
      [_member('papa', 0), _member('mama', 1), _member('zoon', 2)],
      [_location('zoon'), _location('papa')],
    );

    expect(result.map((e) => e.member.userId), ['papa', 'mama', 'zoon']);
    expect(result[0].hasLocation, isTrue);
    expect(result[1].hasLocation, isFalse);
    expect(result[2].location?.userId, 'zoon');
  });

  test('locaties van niet-leden worden genegeerd', () {
    final result = combineMembers([_member('papa', 0)], [_location('onbekend')]);

    expect(result.single.hasLocation, isFalse);
  });
}
