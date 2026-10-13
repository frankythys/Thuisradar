import 'package:flutter_test/flutter_test.dart';
import 'package:thuisradar/features/location/domain/member_location.dart';
import 'package:thuisradar/features/location/domain/travel_mode.dart';
import 'package:thuisradar/features/location/domain/trip_mode_memory.dart';
import 'package:thuisradar/features/location/domain/trip_status.dart';

void main() {
  final start = DateTime(2026, 10, 12, 12);
  late TripModeMemory memory;
  setUp(() => memory = TripModeMemory());
  MemberLocation fix(int seconds, double? speed, {int? steps, String id = 'p'}) => MemberLocation(
    userId: id,
    familyId: 'f',
    latitude: 51,
    longitude: 3,
    updatedAt: start.add(Duration(seconds: seconds)),
    speedMps: speed,
    steps: steps,
  );
  TripStatus update(int seconds, double? speed, {int? steps}) {
    final location = fix(seconds, speed, steps: steps);
    return TripStatus.at(memory.update([location]).single, location.updatedAt);
  }

  /// m/s voor een snelheid in km/u.
  double kmh(double value) => value / 3.6;

  test('wandelen rond 3,6 km/u springt niet naar stilstaand bij één trage meting', () {
    expect(update(0, kmh(4.5)).walking, isTrue);
    expect(update(5, kmh(3.0)).walking, isTrue);
    expect(update(10, kmh(4.2)).walking, isTrue);
    expect(update(15, kmh(2.9)).walking, isTrue);
    expect(update(20, kmh(4.0)).walking, isTrue);
    // De getoonde snelheid blijft die van de laatste wandelmeting.
    expect(update(25, kmh(3.2)).speedKmh, 4);
  });

  test('echt stoppen: twee metingen stil', () {
    update(0, kmh(4.5));
    expect(update(5, 0.1).state, TripState.moving);
    expect(update(10, 0.1).state, TripState.stationary);
  });

  test('stilstaan wordt pas onderweg na twee metingen (GPS-piek thuis)', () {
    update(0, 0);
    expect(update(15, 2.4).state, TripState.stationary);
    expect(update(30, 0.2).state, TripState.stationary);
    expect(update(45, 1.4).state, TripState.stationary);
    expect(update(50, 1.3).walking, isTrue);
  });

  test('een meting zonder snelheid houdt de vorige status', () {
    update(0, kmh(4.5));
    final trip = update(5, null);
    expect(trip.walking, isTrue);
    expect(trip.speedKmh, 5);
    update(10, 0);
    update(15, 0);
    expect(update(20, null).state, TripState.stationary);
  });

  test('fietsen: eigen status, ook rond de wandelgrens en bergaf', () {
    expect(update(0, kmh(16)).cycling, isTrue);
    for (final (second, speed) in [(5, 10.0), (10, 14.0), (15, 9.0), (20, 18.0), (25, 27.0), (30, 15.0)]) {
      final trip = update(second, kmh(speed));
      expect(trip.cycling, isTrue, reason: '$speed km/u na ${second}s');
      expect(trip.mode, TravelMode.bike);
    }
  });

  test('fietser aan een verkeerslicht blijft fietsen, ook na wat trappen', () {
    update(0, kmh(18), steps: 500);
    update(5, kmh(16), steps: 503);
    expect(update(10, 0, steps: 505).cycling, isTrue);
    expect(update(20, 0, steps: 506).cycling, isTrue);
    expect(update(30, 0, steps: 506).cycling, isTrue);
    expect(update(35, kmh(15), steps: 507).cycling, isTrue);
  });

  test('fietser die lang traag gaat (fiets aan de hand) wordt wandelaar', () {
    update(0, kmh(18));
    update(5, kmh(17));
    for (var second = 10; second < 30; second += 5) {
      expect(update(second, kmh(5)).cycling, isTrue);
    }
    expect(update(30, kmh(5)).walking, isTrue);
  });

  test('wandelaar wordt pas fietser na twee snelle metingen', () {
    update(0, kmh(5));
    update(5, kmh(5));
    expect(update(10, kmh(14)).walking, isTrue);
    expect(update(15, kmh(5)).walking, isTrue);
    expect(update(20, kmh(14)).walking, isTrue);
    expect(update(25, kmh(15)).cycling, isTrue);
  });

  test('auto: verkeerslicht en file blijven rijden, geen sprong naar stilstaand', () {
    expect(update(0, 15).driving, isTrue);
    expect(update(5, 1.3).driving, isTrue);
    final red = update(10, 0);
    expect(red.driving, isTrue);
    expect(red.speedKmh, 0);
    expect(update(40, 0).driving, isTrue);
    expect(update(55, 3).driving, isTrue);
    expect(update(60, 15).driving, isTrue);
  });

  test('auto start in de stad: fiets tot twee metingen boven 25 km/u', () {
    update(0, 0);
    update(5, kmh(15));
    expect(update(10, kmh(18)).cycling, isTrue);
    expect(update(15, kmh(30)).cycling, isTrue);
    expect(update(20, kmh(32)).driving, isTrue);
    // Hoge snelheid bewijst meteen een auto.
    memory = TripModeMemory();
    update(0, kmh(15));
    expect(update(5, kmh(55)).driving, isTrue);
  });

  test('geparkeerd: na een minuut stil, en daarna is wandeltempo wandelen', () {
    update(0, 15);
    for (var second = 5; second <= 60; second += 15) {
      update(second, 0);
    }
    expect(update(70, 0).state, TripState.stationary);
    for (var second = 85; second <= 160; second += 15) {
      update(second, 0);
    }
    update(165, 1.3);
    expect(update(170, 1.3).walking, isTrue);
  });

  test('stappen herkennen uitstappen ook na een korte stop', () {
    update(0, 15, steps: 100);
    update(5, 0, steps: 100);
    expect(update(10, 1.3, steps: 114).walking, isTrue);
  });

  test('onderbroken stroom houdt geen oude rijstatus vast', () {
    update(0, 15);
    expect(update(60, 1.3).walking, isTrue);
  });

  test('andere gebruiker en gewone wandeling nemen geen rijstatus over', () {
    update(0, 15);
    final walk = fix(5, 1.3, id: 'walk');
    final result = memory.update([fix(5, 1.3), walk]);
    expect(TripStatus.at(result.first, walk.updatedAt).driving, isTrue);
    expect(TripStatus.at(result.last, walk.updatedAt).walking, isTrue);
    expect(result.first.toJson().keys, isNot(contains('trip_hint')));
    expect(result.first.latitude, 51);
  });

  test('dezelfde meting opnieuw verandert niets', () {
    update(0, kmh(4.5));
    final again = memory.update([fix(0, kmh(4.5))]).single;
    expect(again.tripHint?.moving, isTrue);
    expect(update(0, 0).walking, isTrue);
  });
}
