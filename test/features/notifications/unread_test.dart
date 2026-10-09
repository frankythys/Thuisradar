import 'package:flutter_test/flutter_test.dart';
import 'package:thuisradar/features/location/domain/member_location.dart';
import 'package:thuisradar/features/notifications/domain/family_event.dart';
import 'package:thuisradar/features/notifications/domain/unread.dart';

final _t = DateTime(2026, 10, 9, 12);

FamilyEvent _event(String actor, DateTime at) => FamilyEvent(
  id: at.millisecondsSinceEpoch,
  familyId: 'f',
  actorUserId: actor,
  type: FamilyEventType.sos,
  createdAt: at,
);

MemberLocation _loc(String user, int? battery, {bool? charging}) => MemberLocation(
  userId: user,
  familyId: 'f',
  latitude: 51,
  longitude: 4,
  battery: battery,
  isCharging: charging,
  updatedAt: _t,
);

void main() {
  test('lage batterij: 20% of minder en niet aan het laden', () {
    expect(isLowBattery(_loc('a', 20)), isTrue);
    expect(isLowBattery(_loc('a', 21)), isFalse);
    expect(isLowBattery(_loc('a', 10, charging: true)), isFalse);
    expect(isLowBattery(_loc('a', null)), isFalse);
    expect(lowBatteryUserIds([_loc('a', 5), _loc('b', 80)]), {'a'});
  });

  test('telt gebeurtenissen van anderen na laatst gezien, niet de eigen', () {
    final count = unreadNotifications(
      events: [_event('liam', _t), _event('papa', _t), _event('liam', _t.subtract(const Duration(hours: 2)))],
      userId: 'papa',
      lastSeen: _t.subtract(const Duration(hours: 1)),
      lowBattery: const {},
      seenLowBattery: const {},
    );
    expect(count, 1);
  });

  test('een nieuwe batterijwaarschuwing telt tot ze gezien is', () {
    int count(Set<String> seen) => unreadNotifications(
      events: const [],
      userId: 'papa',
      lastSeen: null,
      lowBattery: {'liam', 'mama'},
      seenLowBattery: seen,
    );
    expect(count(const {}), 2);
    expect(count({'liam'}), 1);
    expect(count({'liam', 'mama'}), 0);
  });
}
