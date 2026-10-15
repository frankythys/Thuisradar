import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:thuisradar/features/location/presentation/trip_text.dart';
import 'package:thuisradar/l10n/l10n.dart';
import 'package:thuisradar/features/location/domain/member_location.dart';
import 'package:thuisradar/features/location/domain/travel_mode.dart';
import 'package:thuisradar/features/location/domain/trip_hint.dart';
import 'package:thuisradar/features/location/domain/trip_status.dart';

final _nl = lookupAppLocalizations(const Locale('nl'));
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
    expect(trip.label(_nl), 'Nog geen locatie gedeeld');
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
    expect(trip.label(_nl), 'Onderweg');
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
    ).description(_nl, location, _now, address: 'Kerkstraat 42, Gent');
    expect(text, 'Onderweg · Kerkstraat 42, Gent · 42 km/u · bijgewerkt 30 s geleden');
  });

  test('een bekende plaats gaat voor het adres', () {
    final location = _location(speedMps: 11.7);
    final text = TripStatus.at(
      location,
      _now,
    ).description(_nl, location, _now, place: 'Thuis', address: 'Kerkstraat 42, Gent');
    expect(text, contains('nabij Thuis'));
    expect(text, isNot(contains('Kerkstraat')));
  });

  test('wandeltempo telt als onderweg, met wandelwoorden', () {
    final location = _location(speedMps: 1.3);
    final trip = TripStatus.at(location, _now);
    expect(trip.state, TripState.moving);
    expect(trip.walking, isTrue);
    expect(
      trip.shortDescription(_nl, location, _now, address: 'Kerkstraat'),
      'Wandelen in de buurt van Kerkstraat',
    );
  });

  test('autotempo is geen wandelen', () {
    final location = _location(speedMps: 11.7);
    final trip = TripStatus.at(location, _now);
    expect(trip.walking, isFalse);
    expect(trip.shortDescription(_nl, location, _now, address: 'N106'), 'Rijden in de buurt van N106');
  });

  test('fietstempo zonder geschiedenis is fietsen', () {
    final location = _location(speedMps: 4.5);
    final trip = TripStatus.at(location, _now);
    expect(trip.cycling, isTrue);
    expect(trip.driving, isFalse);
    expect(
      trip.shortDescription(_nl, location, _now, address: 'Kerkstraat'),
      'Fietsen in de buurt van Kerkstraat',
    );
  });

  test('vervoermiddel bij één snelheid', () {
    expect(travelModeForSpeed(5), TravelMode.walk);
    expect(travelModeForSpeed(11), TravelMode.walk);
    expect(travelModeForSpeed(12), TravelMode.bike);
    expect(travelModeForSpeed(24), TravelMode.bike);
    expect(travelModeForSpeed(25), TravelMode.car);
  });

  test('het geheugen beslist: onderweg met de vorige snelheid, of stil zonder snelheid', () {
    final paused = MemberLocation(
      userId: 'u1',
      familyId: 'fam',
      latitude: 50.85,
      longitude: 4.35,
      speedMps: 0,
      updatedAt: _now,
      tripHint: const TripHint(moving: true, mode: TravelMode.car, speedKmh: 0),
    );
    final trip = TripStatus.at(paused, _now);
    expect(trip.driving, isTrue);
    expect(trip.speedKmh, 0);

    final still = MemberLocation(
      userId: 'u1',
      familyId: 'fam',
      latitude: 50.85,
      longitude: 4.35,
      updatedAt: _now,
      tripHint: const TripHint(moving: false),
    );
    expect(TripStatus.at(still, _now).state, TripState.stationary);
  });
}
