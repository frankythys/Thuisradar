import 'package:flutter_test/flutter_test.dart';
import 'package:thuisradar/features/family/domain/family_member.dart';

void main() {
  test('fromJson leest naam uit het geneste profiel', () {
    final member = FamilyMember.fromJson({
      'user_id': 'u1',
      'role': 'owner',
      'profiles': {'display_name': 'mama'},
    }, colorIndex: 1);

    expect(member.userId, 'u1');
    expect(member.displayName, 'mama');
    expect(member.isOwner, isTrue);
    expect(member.initial, 'M');
    expect(member.colorIndex, 1);
  });

  test('ontbrekend profiel krijgt een standaardnaam', () {
    final member = FamilyMember.fromJson({'user_id': 'u2', 'role': 'member'}, colorIndex: 0);

    expect(member.displayName, 'Gezinslid');
    expect(member.isOwner, isFalse);
  });
}
