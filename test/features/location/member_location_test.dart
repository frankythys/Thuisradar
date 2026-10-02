import 'package:flutter_test/flutter_test.dart';
import 'package:thuisradar/features/location/domain/member_location.dart';

void main() {
  test('toJson en fromJson zijn elkaars omgekeerde', () {
    final original = MemberLocation(
      userId: 'u1',
      familyId: 'f1',
      latitude: 50.85,
      longitude: 4.35,
      accuracyMeters: 12,
      speedMps: 3.5,
      battery: 64,
      isCharging: false,
      updatedAt: DateTime.utc(2026, 10, 2, 16, 5),
    );

    final copy = MemberLocation.fromJson(original.toJson());

    expect(copy.userId, original.userId);
    expect(copy.latitude, original.latitude);
    expect(copy.longitude, original.longitude);
    expect(copy.battery, 64);
    expect(copy.isCharging, isFalse);
    expect(copy.updatedAt.isAtSameMomentAs(original.updatedAt), isTrue);
  });

  test('fromJson accepteert gehele getallen voor coördinaten', () {
    final location = MemberLocation.fromJson({
      'user_id': 'u1',
      'family_id': 'f1',
      'lat': 51,
      'lng': 4,
      'updated_at': '2026-10-02T16:05:00Z',
    });

    expect(location.latitude, 51.0);
    expect(location.battery, isNull);
  });
}
