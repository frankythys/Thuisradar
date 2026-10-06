import 'package:flutter_test/flutter_test.dart';
import 'package:thuisradar/features/location/domain/motion_filter.dart' show distanceMeters;
import 'package:thuisradar/features/location/domain/place_address.dart';

void main() {
  test('het adresraster houdt een coördinaat binnen enkele meters', () {
    const lat = 51.054321;
    const lng = 3.723456;

    final (snappedLat, snappedLng) = snapToAddressGrid(lat, lng);

    // Fijn genoeg voor het juiste huisnummer, niet een halve straat verderop.
    expect(distanceMeters(lat, lng, snappedLat, snappedLng), lessThan(6));
  });

  test('de overkant van een smalle straat krijgt een eigen adressleutel', () {
    // ~12 m noordelijker: de andere kant van de straat, dus een ander adres.
    final here = snapToAddressGrid(51.05000, 3.72000);
    final across = snapToAddressGrid(51.05000 + 12 / 111320, 3.72000);

    expect(here == across, isFalse);
  });
}
