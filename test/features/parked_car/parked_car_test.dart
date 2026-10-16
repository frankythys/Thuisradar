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
}
