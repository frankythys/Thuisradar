import 'package:flutter_test/flutter_test.dart';
import 'package:thuisradar/features/geofencing/domain/geofence_zone.dart';
import 'package:thuisradar/features/places/domain/place.dart';

Place _place(String id, {double lat = 51.0, double lng = 4.0, int radius = 150}) => Place(
  id: id,
  familyId: 'f1',
  name: id,
  latitude: lat,
  longitude: lng,
  radiusMeters: radius,
  icon: 'home',
);

void main() {
  test('zone-id bevat plaats, ligging en straal en geeft de plaats terug', () {
    final zone = GeofenceZone.fromPlace(_place('thuis'));
    expect(zone.id, 'tr1|thuis|51.00000|4.00000|150');
    expect(GeofenceZone.placeIdOf(zone.id), 'thuis');
    expect(GeofenceZone.placeIdOf('iets-anders'), isNull);
  });

  test('kleine plaats (50 m) krijgt een zone van 100 m', () {
    expect(GeofenceZone.fromPlace(_place('thuis', radius: 50)).radiusMeters, 100);
    expect(GeofenceZone.fromPlace(_place('thuis', radius: 300)).radiusMeters, 300);
  });

  test('eerste start: Thuis en Werk worden geregistreerd', () {
    final plan = planGeofenceSync(
      registeredIds: const [],
      places: [_place('thuis'), _place('werk', lat: 51.2)],
    );
    expect(plan.toRemove, isEmpty);
    expect(plan.toAdd.map((z) => z.placeId), ['thuis', 'werk']);
  });

  test('niets gewijzigd: niets opnieuw registreren', () {
    final places = [_place('thuis'), _place('werk', lat: 51.2)];
    final registered = places.map((p) => GeofenceZone.fromPlace(p).id);
    expect(planGeofenceSync(registeredIds: registered, places: places).isEmpty, isTrue);
  });

  test('Thuis verschoven en straal groter: enkel Thuis opnieuw', () {
    final before = [_place('thuis'), _place('werk', lat: 51.2)];
    final registered = before.map((p) => GeofenceZone.fromPlace(p).id).toList();
    final after = [_place('thuis', lat: 51.0004, radius: 200), _place('werk', lat: 51.2)];

    final plan = planGeofenceSync(registeredIds: registered, places: after);
    expect(plan.toRemove, [registered.first]);
    expect(plan.toAdd.single.id, 'tr1|thuis|51.00040|4.00000|200');
  });

  test('plaats verwijderd: zone weg; zones van andere apps blijven', () {
    final registered = [GeofenceZone.fromPlace(_place('thuis')).id, 'ander-plugin-zone'];
    final plan = planGeofenceSync(registeredIds: registered, places: const []);
    expect(plan.toRemove, [registered.first]);
    expect(plan.toAdd, isEmpty);
  });
}
