import 'package:flutter_test/flutter_test.dart';
import 'package:thuisradar/features/sos/domain/sos_alert.dart';

SosAlert _alert(String id, String userId, {bool active = true}) => SosAlert(
  id: id,
  familyId: 'fam',
  userId: userId,
  latitude: 51.0,
  longitude: 3.7,
  active: active,
  createdAt: DateTime(2026, 1, 2, 10),
);

void main() {
  test('fromJson leest status, coördinaten en tijden', () {
    final alert = SosAlert.fromJson({
      'id': 'a1',
      'family_id': 'fam',
      'user_id': 'u1',
      'lat': 51.05,
      'lng': 3.72,
      'status': 'active',
      'created_at': '2026-01-02T09:00:00Z',
      'resolved_at': null,
    });

    expect(alert.id, 'a1');
    expect(alert.active, isTrue);
    expect(alert.latitude, 51.05);
    expect(alert.resolvedAt, isNull);
  });

  test('een opgelost alarm is niet actief', () {
    final alert = SosAlert.fromJson({
      'id': 'a2',
      'family_id': 'fam',
      'user_id': 'u1',
      'lat': 51.0,
      'lng': 3.7,
      'status': 'resolved',
      'created_at': '2026-01-02T09:00:00Z',
      'resolved_at': '2026-01-02T09:05:00Z',
    });

    expect(alert.active, isFalse);
    expect(alert.resolvedAt, isNotNull);
  });

  test('sosToShow kiest het alarm van een ander lid', () {
    final result = sosToShow([_alert('a1', 'other'), _alert('a2', 'me')], myUserId: 'me', dismissed: {});
    expect(result?.id, 'a1');
  });

  test('sosToShow negeert eigen alarmen', () {
    final result = sosToShow([_alert('a2', 'me')], myUserId: 'me', dismissed: {});
    expect(result, isNull);
  });

  test('sosToShow slaat weggetikte alarmen over', () {
    final result = sosToShow(
      [_alert('a1', 'other'), _alert('a3', 'other2')],
      myUserId: 'me',
      dismissed: {'a1'},
    );
    expect(result?.id, 'a3');
  });
}
