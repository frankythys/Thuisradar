import 'package:flutter_test/flutter_test.dart';
import 'package:thuisradar/features/places/domain/place.dart';
import 'package:thuisradar/features/places/domain/place_presence.dart';
import 'package:thuisradar/features/places/domain/place_status.dart';

const _home = Place(
  id: 'p1',
  familyId: 'fam',
  name: 'Thuis',
  latitude: 51,
  longitude: 3.7,
  radiusMeters: 150,
  icon: 'home',
);

void main() {
  test('koppelt een aanwezig lid aan de plaatsnaam en sinds-tijd', () {
    final map = currentPlaceByUser(
      const [_home],
      [PlacePresence(userId: 'u1', placeId: 'p1', isInside: true, since: DateTime(2026, 1, 2, 17, 42))],
    );

    expect(map['u1']?.name, 'Thuis');
    expect(map['u1']?.since, DateTime(2026, 1, 2, 17, 42));
  });

  test('wie niet binnen is, verschijnt niet', () {
    final map = currentPlaceByUser(
      const [_home],
      const [PlacePresence(userId: 'u1', placeId: 'p1', isInside: false)],
    );
    expect(map, isEmpty);
  });
}
