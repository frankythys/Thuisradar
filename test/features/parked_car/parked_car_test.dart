import 'package:flutter_test/flutter_test.dart';
import 'package:thuisradar/features/parked_car/domain/parked_car.dart';

void main() {
  test('leest de parkeerplek met de eigenaar, familie en opslagtijd', () {
    final parkedAt = DateTime.utc(2026, 10, 16, 9, 30);
    final car = ParkedCar.fromJson({
      'user_id': 'user-1',
      'family_id': 'family-1',
      'lat': 51.2,
      'lng': 3.8,
      'parked_at': parkedAt.toIso8601String(),
    });

    expect(car.userId, 'user-1');
    expect(car.familyId, 'family-1');
    expect(car.latitude, 51.2);
    expect(car.longitude, 3.8);
    expect(car.parkedAt, parkedAt.toLocal());
  });

  group('parkedCarStartPoint', () {
    final car = ParkedCar(
      userId: 'u',
      familyId: 'f',
      latitude: 51.1,
      longitude: 4.1,
      parkedAt: DateTime(2026, 10, 16),
    );
    const fresh = (latitude: 51.2, longitude: 4.2);
    const shared = (latitude: 51.3, longitude: 4.3);

    test('een bestaande parkeerplek gaat voor', () {
      expect(parkedCarStartPoint(existing: car, fresh: fresh, lastShared: shared), (
        latitude: 51.1,
        longitude: 4.1,
      ));
    });

    test('anders een verse GPS-meting, dan de laatst gedeelde locatie', () {
      expect(parkedCarStartPoint(fresh: fresh, lastShared: shared), fresh);
      expect(parkedCarStartPoint(lastShared: shared), shared);
      expect(parkedCarStartPoint(), isNull);
    });
  });
}
