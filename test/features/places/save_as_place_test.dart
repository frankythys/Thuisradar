import 'package:flutter_test/flutter_test.dart';
import 'package:thuisradar/features/location/domain/member_location.dart';
import 'package:thuisradar/features/places/domain/place.dart';
import 'package:thuisradar/features/places/domain/save_as_place.dart';

void main() {
  final now = DateTime(2026, 10, 9, 14);
  MemberLocation at(double lat, double lng, {double speed = 0, Duration ago = const Duration(seconds: 20)}) =>
      MemberLocation(
        userId: 'u',
        familyId: 'f',
        latitude: lat,
        longitude: lng,
        speedMps: speed,
        updatedAt: now.subtract(ago),
      );
  const home = Place(
    id: 'p',
    familyId: 'f',
    name: 'Thuis',
    latitude: 51.2,
    longitude: 4.4,
    radiusMeters: 150,
    icon: 'home',
  );

  test('stilstaan buiten een plaats: opslaan mag', () {
    expect(canSaveAsPlace(at(51.25, 4.45), const [home], now), isTrue);
  });

  test('binnen een opgeslagen plaats: geen knop', () {
    expect(canSaveAsPlace(at(51.2, 4.4), const [home], now), isFalse);
  });

  test('onderweg of verouderde locatie: geen knop', () {
    expect(canSaveAsPlace(at(51.25, 4.45, speed: 12), const [home], now), isFalse);
    expect(canSaveAsPlace(at(51.25, 4.45, ago: const Duration(hours: 2)), const [home], now), isFalse);
    expect(canSaveAsPlace(null, const [home], now), isFalse);
  });
}
