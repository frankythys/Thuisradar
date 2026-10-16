import 'package:flutter_test/flutter_test.dart';
import 'package:thuisradar/features/location/domain/device_reading.dart';
import 'package:thuisradar/features/location/domain/motion_filter.dart';

void main() {
  final base = DateTime(2026, 1, 2, 10);

  DevicePosition pos(double lat, double lng, DateTime at, {double? accuracy, double? speed}) =>
      DevicePosition(latitude: lat, longitude: lng, timestamp: at, accuracyMeters: accuracy, speedMps: speed);

  test('een nauwkeurige fix wordt aanvaard', () {
    final accepted = MotionFilter().accept(pos(51, 3, base, accuracy: 10), base);
    expect(accepted, isNotNull);
  });

  test('een betrouwbare GPS-snelheid meldt beweging vanaf de tweede fix', () {
    final filter = MotionFilter();
    final at = base.add(const Duration(seconds: 5));
    filter.accept(pos(51, 3, base, accuracy: 10, speed: 8), base);
    final accepted = filter.accept(pos(51.0004, 3, at, accuracy: 10, speed: 8), at);

    expect(accepted!.speedMps, 8);
    expect(filter.wantsFastUpdates, isTrue);
  });

  test('de eerste fix na opstart meldt nooit meteen rijden', () {
    final filter = MotionFilter();
    final accepted = filter.accept(pos(51, 3, base, accuracy: 10, speed: 8), base);

    expect(accepted, isNotNull);
    expect(accepted!.speedMps, isNull);
    // Wel sneller meten, zodat een echte rit snel bevestigd wordt.
    expect(filter.wantsFastUpdates, isTrue);
  });

  test('rood licht: na een rit is echt nul meteen stil, kruipen pas na twee metingen', () {
    MotionFilter driving() {
      final filter = MotionFilter();
      filter.accept(pos(51, 3, base, accuracy: 5, speed: 10), base);
      final at = base.add(const Duration(seconds: 5));
      expect(filter.accept(pos(51.0005, 3, at, accuracy: 5, speed: 10), at)!.speedMps, 10);
      return filter;
    }

    final stop = base.add(const Duration(seconds: 10));
    expect(driving().accept(pos(51.0005, 3, stop, accuracy: 5, speed: 0), stop)!.speedMps, 0);
    final crawl = driving();
    expect(crawl.accept(pos(51.0005, 3, stop, accuracy: 5, speed: 0.6), stop)!.speedMps, isNull);
    final later = base.add(const Duration(seconds: 15));
    expect(crawl.accept(pos(51.0005, 3, later, accuracy: 5, speed: 0.6), later)!.speedMps, 0);
  });

  group('stop-and-go na een rit', () {
    /// Rijden, dan stil aan het rode licht op [stopAt] s.
    MotionFilter stoppedAt(int stopAt) {
      final filter = MotionFilter();
      filter.accept(pos(51, 3, base, accuracy: 5, speed: 10), base);
      final at = base.add(const Duration(seconds: 5));
      filter.accept(pos(51.0005, 3, at, accuracy: 5, speed: 10), at);
      final stop = base.add(Duration(seconds: stopAt));
      expect(filter.accept(pos(51.0005, 3, stop, accuracy: 5, speed: 0), stop)!.speedMps, 0);
      return filter;
    }

    test('vertrek na een rood licht: de eerste bewegende meting is meteen rijden', () {
      final filter = stoppedAt(10);
      final wait = base.add(const Duration(seconds: 35));
      filter.accept(pos(51.0005, 3, wait, accuracy: 5, speed: 0), wait);
      final go = base.add(const Duration(seconds: 40));
      // ±11 m in 5 s aan 2 m/s: echt vertrokken.
      expect(filter.accept(pos(51.0006, 3, go, accuracy: 5, speed: 2), go)!.speedMps, 2);
    });

    test('een snelheidspiek zonder verplaatsing aan het licht blijft stil', () {
      final filter = stoppedAt(10);
      final spike = base.add(const Duration(seconds: 15));
      expect(filter.accept(pos(51.0005, 3, spike, accuracy: 5, speed: 2), spike)!.speedMps, 0);
    });

    test('lang na de rit (geparkeerd) vraagt vertrek weer twee metingen', () {
      final filter = stoppedAt(10);
      final go = base.add(const Duration(minutes: 5));
      filter.accept(pos(51.0005, 3, go.subtract(const Duration(seconds: 5)), accuracy: 5, speed: 0), go);
      expect(filter.accept(pos(51.0006, 3, go, accuracy: 5, speed: 2), go)!.speedMps ?? 0, 0);
    });
  });

  test('GPS-snelheid van 6 km/u zonder verplaatsing meldt geen beweging', () {
    final filter = MotionFilter();
    for (var i = 0; i < 12; i++) {
      final at = base.add(Duration(seconds: i * 5));
      final accepted = filter.accept(pos(51, 3, at, accuracy: 10, speed: 1.67), at);
      expect(accepted!.speedMps ?? 0, lessThan(1.5));
    }
  });

  test('wandelsnelheid wordt bevestigd zodra verplaatsing buiten GPS-ruis valt', () {
    final filter = MotionFilter();
    DevicePosition? accepted;
    for (var i = 0; i < 5; i++) {
      final at = base.add(Duration(seconds: i * 5));
      accepted = filter.accept(pos(51 + i * 0.000075, 3, at, accuracy: 10, speed: 1.67), at);
    }
    expect(accepted!.speedMps, 1.67);
  });

  test('een rustige wandeling (4,5 km/u) wordt beweging en vraagt snelle uploads', () {
    final filter = MotionFilter();
    DevicePosition? accepted;
    for (var i = 0; i < 8; i++) {
      final at = base.add(Duration(seconds: i * 5));
      // 1,25 m/s: elke 5 s ruim 6 m verder.
      accepted = filter.accept(pos(51 + i * 0.0000562, 3, at, accuracy: 8, speed: 1.25), at);
    }
    expect(accepted!.speedMps, 1.25);
    expect(filter.wantsFastUpdates, isTrue);
  });

  test('een grove fix (binnenshuis) wordt bewaard maar meldt geen beweging', () {
    final accepted = MotionFilter().accept(pos(51, 3, base, accuracy: 80), base);

    expect(accepted, isNotNull);
    expect(accepted!.speedMps, isNull);
  });

  test('een volledig onbruikbare fix wordt geweigerd', () {
    expect(MotionFilter().accept(pos(51, 3, base, accuracy: 250), base), isNull);
  });

  test('opeenvolgende grove fixes ver uiteen melden nooit beweging', () {
    final filter = MotionFilter();
    var at = base;
    DevicePosition? last;
    for (var i = 0; i < 3; i++) {
      // Elke stap ~200 m, maar alle fixes zijn grof: geen bewijs van rijden.
      last = filter.accept(pos(51 + i * 0.0018, 3, at, accuracy: 80), at);
      at = at.add(const Duration(seconds: 30));
    }

    expect(last, isNotNull);
    expect(last!.speedMps, isNull);
    expect(filter.wantsFastUpdates, isFalse);
  });

  group('weigerreden voor de locatiediagnose', () {
    test('te onnauwkeurig (>100 m)', () {
      final filter = MotionFilter();
      expect(filter.accept(pos(51, 3, base, accuracy: 140), base), isNull);
      expect(filter.lastRejection, RejectReason.inaccurate);
    });

    test('te oud', () {
      final filter = MotionFilter();
      final now = base.add(const Duration(minutes: 3));
      expect(filter.accept(pos(51, 3, base, accuracy: 10), now), isNull);
      expect(filter.lastRejection, RejectReason.stale);
    });

    test('niet nieuwer dan de vorige', () {
      final filter = MotionFilter()..accept(pos(51, 3, base, accuracy: 10), base);
      expect(filter.accept(pos(51, 3, base, accuracy: 10), base), isNull);
      expect(filter.lastRejection, RejectReason.notNewer);
    });

    test('onmogelijke sprong', () {
      final filter = MotionFilter()..accept(pos(51, 3, base, accuracy: 10), base);
      final at = base.add(const Duration(seconds: 5));
      expect(filter.accept(pos(51.1, 3, at, accuracy: 10), at), isNull);
      expect(filter.lastRejection, RejectReason.jump);
    });

    test('aanvaard wist de vorige reden', () {
      final filter = MotionFilter()..accept(pos(51, 3, base, accuracy: 140), base);
      expect(filter.accept(pos(51, 3, base, accuracy: 10), base), isNotNull);
      expect(filter.lastRejection, isNull);
    });
  });
}
