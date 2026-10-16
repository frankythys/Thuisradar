import 'package:flutter_test/flutter_test.dart';
import 'package:thuisradar/features/location/domain/member_location.dart';
import 'package:thuisradar/features/location/domain/motion_activity.dart';
import 'package:thuisradar/features/location/domain/trip_mode_memory.dart';
import 'package:thuisradar/features/location/domain/trip_status.dart';

void main() {
  final start = DateTime(2026, 10, 12, 12);
  late TripModeMemory memory;
  setUp(() => memory = TripModeMemory());
  MemberLocation fix(int seconds, double? speed, {int? steps, String id = 'p', MotionActivity? activity}) =>
      MemberLocation(
        userId: id,
        familyId: 'f',
        latitude: 51,
        longitude: 3,
        updatedAt: start.add(Duration(seconds: seconds)),
        speedMps: speed,
        steps: steps,
        activity: activity,
      );
  TripStatus update(int seconds, double? speed, {int? steps, MotionActivity? activity}) {
    final location = fix(seconds, speed, steps: steps, activity: activity);
    return TripStatus.at(memory.update([location]).single, location.updatedAt);
  }

  /// m/s voor een snelheid in km/u.
  double kmh(double value) => value / 3.6;

  /// Wandelen: ±8 stappen per 5 s.
  int walked(int seconds) => 1000 + seconds * 8 ~/ 5;

  test('stappen die oplopen: wandelen, ook heel traag', () {
    update(0, 0, steps: 1000);
    expect(update(5, kmh(4), steps: walked(5)).walking, isTrue);
    expect(update(10, kmh(4.5), steps: walked(10)).walking, isTrue);
    expect(update(15, kmh(6), steps: walked(15)).walking, isTrue);
  });

  test('bewegen zonder stappen is rijden, ook in de file aan 5 km/u', () {
    update(0, 0, steps: 1394);
    for (final (second, speed) in [(10, 12.0), (15, 14.0), (20, 9.0), (25, 5.0), (30, 4.0)]) {
      expect(update(second, kmh(speed), steps: 1394).driving, isTrue, reason: '$speed km/u');
    }
  });

  test('vertrek is meteen onderweg, stoppen meteen stilstaand', () {
    update(0, 0, steps: 500);
    expect(update(5, kmh(20), steps: 500).driving, isTrue);
    final red = update(10, 0, steps: 500);
    expect(red.state, TripState.stationary);
    expect(red.speedKmh, isNull);
  });

  test('de auto blijft onthouden bij verkeerslicht en een lange stop in de file', () {
    update(0, kmh(60), steps: 500);
    for (var second = 5; second <= 180; second += 15) {
      expect(update(second, 0, steps: 500).state, TripState.stationary);
    }
    expect(update(185, kmh(8), steps: 500).driving, isTrue);
  });

  test('uitstappen: stappen beëindigen de rit, ook na een korte stop', () {
    update(0, kmh(50), steps: 100);
    update(5, 0, steps: 100);
    update(10, 0, steps: 108);
    expect(update(15, 1.2, steps: 116).walking, isTrue);
  });

  test('fiets: drie minuten aan fietstempo zonder stappen en nooit autosnelheid', () {
    var trip = update(0, kmh(18), steps: 300);
    for (var second = 5; second <= 180; second += 5) {
      trip = update(second, kmh(second.isEven ? 16 : 22), steps: 300);
    }
    expect(trip.cycling, isTrue);
    // Een fietser aan een verkeerslicht (voet aan de grond) blijft fietsen.
    update(185, 0, steps: 302);
    expect(update(200, kmh(15), steps: 303).cycling, isTrue);
  });

  test('een auto die al eens snel reed, wordt nooit een fiets', () {
    update(0, kmh(50), steps: 300);
    var trip = update(5, kmh(18), steps: 300);
    for (var second = 10; second <= 400; second += 5) {
      trip = update(second, kmh(18), steps: 300);
    }
    expect(trip.driving, isTrue);
  });

  test('zonder stappenteller: onder 9 km/u wandelen, daarboven rijden (zoals vroeger)', () {
    expect(update(0, kmh(5)).walking, isTrue);
    expect(update(5, kmh(30)).driving, isTrue);
    // Een rit blijft een rit aan een verkeerslicht.
    update(10, 0);
    expect(update(30, kmh(6)).driving, isTrue);
    // Na anderhalve minuut stil is wandeltempo weer wandelen.
    for (var second = 35; second <= 140; second += 15) {
      update(second, 0);
    }
    expect(update(145, kmh(5)).walking, isTrue);
  });

  test('een meting zonder snelheid houdt de vorige status', () {
    update(0, 0, steps: 1000);
    update(5, kmh(4.5), steps: walked(5));
    final trip = update(10, null, steps: walked(10));
    expect(trip.walking, isTrue);
    expect(trip.speedKmh, 5);
    update(15, 0, steps: walked(10));
    expect(update(20, null, steps: walked(10)).state, TripState.stationary);
  });

  test('onderbroken stroom houdt geen oude rit vast', () {
    update(0, kmh(50));
    expect(update(120, kmh(5)).walking, isTrue);
  });

  test('een nieuwe dag (lagere stappenteller) begint opnieuw te tellen', () {
    update(0, 0, steps: 9000);
    update(5, 0, steps: 10);
    expect(update(10, kmh(5), steps: 26).walking, isTrue);
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

  group('activiteitsherkenning van het toestel', () {
    const vehicle = MotionActivity.vehicle;
    const bicycle = MotionActivity.bicycle;
    const foot = MotionActivity.foot;

    test('voertuig zonder stappenteller: meteen een auto, ook traag in de file', () {
      // Zonder herkenning en zonder stappen is 7 km/u een wandeling.
      expect(update(0, kmh(7)).walking, isTrue);
      memory = TripModeMemory();
      expect(update(0, kmh(7), activity: vehicle).driving, isTrue);
      expect(update(5, kmh(4), activity: vehicle).driving, isTrue);
    });

    test('fiets aan 35 km/u (speed pedelec, bergaf) blijft een fiets', () {
      expect(update(0, kmh(36)).driving, isTrue);
      memory = TripModeMemory();
      for (var second = 0; second <= 30; second += 5) {
        expect(update(second, kmh(36), steps: 500, activity: bicycle).cycling, isTrue, reason: '${second}s');
      }
      // Valt de herkenning even weg, dan blijft het een fiets.
      expect(update(35, kmh(38), steps: 500).cycling, isTrue);
    });

    test('boven 50 km/u wint de snelheid, ook als het toestel fiets zegt', () {
      update(0, kmh(30), activity: bicycle);
      expect(update(5, kmh(55), activity: bicycle).driving, isTrue);
      expect(update(10, kmh(40)).driving, isTrue);
    });

    test('trappen telt soms als stappen: fiets wint aan fietstempo', () {
      update(0, kmh(15), steps: 1000, activity: bicycle);
      expect(update(5, kmh(15), steps: 1010, activity: bicycle).cycling, isTrue);
      // Uitgestapt en te voet aan wandeltempo: de stappen winnen, ook al zegt
      // de herkenning nog even "fiets".
      expect(update(10, kmh(5), steps: 1020, activity: bicycle).walking, isTrue);
    });

    test('voertuig na fiets aan fietstempo: blijft een fiets (herkenning vergist zich)', () {
      update(0, kmh(20), activity: bicycle);
      expect(update(5, kmh(20), activity: vehicle).cycling, isTrue);
      expect(update(10, kmh(12), activity: vehicle).cycling, isTrue);
    });

    test('voertuig na fiets aan autosnelheid: auto (fiets op het fietsrek)', () {
      update(0, kmh(20), activity: bicycle);
      expect(update(5, kmh(40), activity: vehicle).driving, isTrue);
      expect(update(10, kmh(20), activity: vehicle).driving, isTrue);
    });

    test('stappen aan fietstempo met "voertuig": trappen, dus een fiets', () {
      update(0, kmh(12), steps: 1000, activity: vehicle);
      expect(update(5, kmh(12), steps: 1012, activity: vehicle).cycling, isTrue);
    });

    test('een auto die op snelheid reed, wordt geen fiets door een losse "fiets"', () {
      update(0, kmh(60), activity: vehicle);
      update(5, kmh(60), activity: vehicle);
      expect(update(10, kmh(20), activity: bicycle).driving, isTrue);
    });

    test('te voet zonder stappenteller beëindigt de rit bij een stop', () {
      update(0, kmh(50));
      expect(update(5, 0).state, TripState.stationary);
      // Zonder herkenning blijft het voertuig 90 s onthouden.
      expect(update(10, kmh(5), activity: foot).walking, isTrue);
    });

    test('zonder herkenning werkt alles zoals vroeger', () {
      update(0, 0, steps: 1394);
      expect(update(5, kmh(12), steps: 1394).driving, isTrue);
      expect(update(10, kmh(5), steps: 1394).driving, isTrue);
    });
  });
}
