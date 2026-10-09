import 'package:flutter_test/flutter_test.dart';
import 'package:thuisradar/features/location/domain/member_location.dart';
import 'package:thuisradar/features/places/domain/confirmed_presence.dart';
import 'package:thuisradar/features/places/domain/place.dart';
import 'package:thuisradar/features/places/domain/place_presence.dart';

void main() {
  const home = Place(
    id: 'home',
    familyId: 'f',
    name: 'Thuis',
    latitude: 51.2,
    longitude: 4.4,
    radiusMeters: 100,
    icon: 'home',
  );
  const inside = PlacePresence(userId: 'u', placeId: 'home', isInside: true);
  MemberLocation at(double lat, double lng) => MemberLocation(
    userId: 'u',
    familyId: 'f',
    latitude: lat,
    longitude: lng,
    updatedAt: DateTime(2026, 10, 9, 10),
  );

  test('GPS bij de plaats: aanwezigheid blijft', () {
    expect(confirmedPresence([inside], [home], [at(51.2005, 4.4005)]), [inside]);
  });

  test('GPS net buiten de straal (binnenshuis-afwijking): aanwezigheid blijft', () {
    // ±180 m van het midden: binnen straal (100) + speling (150).
    expect(confirmedPresence([inside], [home], [at(51.2016, 4.4)]), [inside]);
  });

  test('GPS kilometers verder: oude aanwezigheid telt niet', () {
    expect(confirmedPresence([inside], [home], [at(51.25, 4.45)]), isEmpty);
  });

  test('zonder locatie blijft de aanwezigheid gelden', () {
    expect(confirmedPresence([inside], [home], const []), [inside]);
  });

  test('verse GPS binnen de cirkel telt meteen als aanwezig', () {
    final now = DateTime(2026, 10, 9, 10, 0, 20);
    final ids = presentUserIdsAt(home, const [], [at(51.2003, 4.4)], now);
    expect(ids, {'u'});
  });

  test('oude GPS binnen de cirkel telt niet zonder bevestiging', () {
    final now = DateTime(2026, 10, 9, 12);
    expect(presentUserIdsAt(home, const [], [at(51.2003, 4.4)], now), isEmpty);
    expect(presentUserIdsAt(home, const [inside], [at(51.2003, 4.4)], now), {'u'});
  });
}
