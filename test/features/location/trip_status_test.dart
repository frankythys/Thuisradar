import 'package:flutter_test/flutter_test.dart';
import 'package:thuisradar/features/location/domain/member_location.dart';
import 'package:thuisradar/features/location/domain/trip_status.dart';

final _now = DateTime(2026, 10, 2, 18, 5);

MemberLocation _location({double? speedMps, Duration age = Duration.zero}) => MemberLocation(
  userId: 'u1',
  familyId: 'fam',
  latitude: 50.85,
  longitude: 4.35,
  speedMps: speedMps,
  updatedAt: _now.subtract(age),
);

void main() {
  test('geen locatie is ontbrekend', () {
    final trip = TripStatus.at(null, _now);
    expect(trip.state, TripState.missing);
    expect(trip.speedKmh, isNull);
    expect(trip.label, 'Nog geen locatie gedeeld');
  });

  test('stilstaan (of onbekend) toont nooit een snelheid', () {
    final stationary = TripStatus.at(_location(speedMps: 0.8), _now);
    expect(stationary.state, TripState.stationary);
    expect(stationary.speedKmh, isNull);

    final unknown = TripStatus.at(_location(), _now);
    expect(unknown.state, TripState.unknown);
    expect(unknown.speedKmh, isNull);
  });

  test('onderweg rekent m/s om naar km/u', () {
    final trip = TripStatus.at(_location(speedMps: 11.7), _now);
    expect(trip.state, TripState.moving);
    expect(trip.speedKmh, 42);
    expect(trip.label, 'Onderweg');
  });

  test('te oude metingen zijn niet actueel', () {
    expect(
      TripStatus.at(_location(speedMps: 5, age: const Duration(seconds: 60)), _now).state,
      TripState.stale,
    );
    expect(TripStatus.at(_location(age: const Duration(seconds: 120)), _now).state, TripState.stale);
  });

  test('beschrijving bevat straat, gemeente, snelheid en leeftijd', () {
    final location = _location(speedMps: 11.7, age: const Duration(seconds: 30));
    final text = TripStatus.at(
      location,
      _now,
    ).description(location, _now, address: 'Kerkstraat 42, Gent');
    expect(text, 'Onderweg · Kerkstraat 42, Gent · 42 km/u · bijgewerkt 30 s geleden');
  });

  test('een bekende plaats gaat voor het adres', () {
    final location = _location(speedMps: 11.7);
    final text = TripStatus.at(
      location,
      _now,
    ).description(location, _now, place: 'Thuis', address: 'Kerkstraat 42, Gent');
    expect(text, contains('nabij Thuis'));
    expect(text, isNot(contains('Kerkstraat')));
  });
}
