import 'package:flutter_test/flutter_test.dart';
import 'package:thuisradar/features/places/domain/geofence.dart';

DateTime _t(int minute) => DateTime(2026, 1, 2, 8, minute);

void main() {
  const radius = 150.0;

  test('onnauwkeurige meting (accuracy > 100 m) verandert niets', () {
    const inside = PresenceState(isInside: true);
    final result = evaluateGeofence(
      current: inside,
      distanceMeters: 5000, // ver weg
      radiusMeters: radius,
      at: _t(0),
      accuracyMeters: 150,
    );
    expect(result.transition, isNull);
    expect(result.state.isInside, isTrue);
  });

  test('binnenkomen bij de eerste meting binnen de straal = aankomst', () {
    final result = evaluateGeofence(
      current: const PresenceState(),
      distanceMeters: 80,
      radiusMeters: radius,
      at: _t(0),
      accuracyMeters: 20,
    );
    expect(result.transition, GeofenceTransition.arrival);
    expect(result.state.isInside, isTrue);
    expect(result.state.since, _t(0));
  });

  test('al binnen en nog binnen = geen nieuwe overgang', () {
    final result = evaluateGeofence(
      current: PresenceState(isInside: true, since: _t(0)),
      distanceMeters: 100,
      radiusMeters: radius,
      at: _t(5),
    );
    expect(result.transition, isNull);
    expect(result.state.isInside, isTrue);
  });

  test('in de hysterese-band (straal..straal+50) verandert er niets', () {
    final result = evaluateGeofence(
      current: PresenceState(isInside: true, since: _t(0)),
      distanceMeters: 180, // tussen 150 en 200
      radiusMeters: radius,
      at: _t(5),
    );
    expect(result.transition, isNull);
    expect(result.state.isInside, isTrue);
  });

  test('één meting buiten de zone is nog geen vertrek', () {
    final result = evaluateGeofence(
      current: PresenceState(isInside: true, since: _t(0)),
      distanceMeters: 300,
      radiusMeters: radius,
      at: _t(5),
    );
    expect(result.transition, isNull);
    expect(result.state.isInside, isTrue);
    expect(result.state.outsideCount, 1);
  });

  test('tweede opeenvolgende meting buiten = vertrek', () {
    final first = evaluateGeofence(
      current: PresenceState(isInside: true, since: _t(0)),
      distanceMeters: 300,
      radiusMeters: radius,
      at: _t(5),
    );
    final second = evaluateGeofence(
      current: first.state,
      distanceMeters: 320,
      radiusMeters: radius,
      at: _t(6),
    );
    expect(second.transition, GeofenceTransition.departure);
    expect(second.state.isInside, isFalse);
  });

  test('vertrek ook na 3 minuten buiten, met één meting', () {
    final result = evaluateGeofence(
      current: PresenceState(isInside: true, since: _t(0), outsideSince: _t(1), outsideCount: 1),
      distanceMeters: 300,
      radiusMeters: radius,
      at: _t(4), // 3 min na outsideSince
    );
    expect(result.transition, GeofenceTransition.departure);
    expect(result.state.isInside, isFalse);
  });

  test('terug binnenkomen na buiten = nieuwe aankomst', () {
    final result = evaluateGeofence(
      current: const PresenceState(),
      distanceMeters: 50,
      radiusMeters: radius,
      at: _t(10),
    );
    expect(result.transition, GeofenceTransition.arrival);
  });
}
