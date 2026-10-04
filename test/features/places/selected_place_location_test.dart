import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:thuisradar/features/places/domain/selected_place_location.dart';

void main() {
  test('kaart verschuiven verwijdert het oude adres', () {
    final selection = SelectedPlaceLocation(const LatLng(51, 4));
    selection.resolve(selection.beginSearch(), const LatLng(52, 4), 'Adres');
    selection.move(const LatLng(52, 5), userGesture: true);
    expect(selection.address, isNull);
    expect(selection.center.longitude, 5);
  });
  test('laat zoekresultaat overschrijft geen gebruikerskeuze', () {
    final selection = SelectedPlaceLocation(const LatLng(51, 4));
    final revision = selection.beginSearch();
    selection.move(const LatLng(51, 5), userGesture: true);
    expect(selection.resolve(revision, const LatLng(52, 4), 'Oud'), isFalse);
    expect(selection.center.longitude, 5);
  });
  test('tekst bewerken maakt eerder gevonden adres ongeldig', () {
    final selection = SelectedPlaceLocation(const LatLng(51, 4));
    final revision = selection.beginSearch();
    selection.editAddress();
    expect(selection.resolve(revision, const LatLng(52, 4), 'Oud'), isFalse);
    expect(selection.address, isNull);
  });
}
