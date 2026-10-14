import 'package:flutter_test/flutter_test.dart';
import 'package:thuisradar/features/map/domain/walking_cycle.dart';

void main() {
  /// Twee houdingen liggen dicht bij elkaar (geen sprong tussen beelden).
  void expectClose(SneakerPose a, SneakerPose b, {String? reason}) {
    expect(a.x, closeTo(b.x, 1e-3), reason: reason);
    expect(a.lift, closeTo(b.lift, 1e-3), reason: reason);
    expect(a.pitchDegrees, closeTo(b.pitchDegrees, 0.05), reason: reason);
  }

  group('tempo', () {
    test('48 beelden van 33 ms: samen 1,6 s', () {
      expect(kWalkingLoopFrames, 48);
      final total = kWalkFrameDuration * kWalkingLoopFrames;
      expect((total - const Duration(milliseconds: kWalkCycleMs)).inMicroseconds.abs(), lessThan(1000));
    });
  });

  group('sneakerPose', () {
    test('naadloos: fase 1 is weer fase 0, ook voor de achterste voet', () {
      expectClose(sneakerPose(1), sneakerPose(0));
      expectClose(sneakerPose(1.5), sneakerPose(0.5));
      expectClose(sneakerPose(0.9999), sneakerPose(0), reason: 'einde sluit aan op begin');
    });

    test('geen sprong tussen steun- en zwaaifase', () {
      expectClose(sneakerPose(kStance - 1e-5), sneakerPose(kStance));
    });

    test('vloeiend: elke stap van één beeld is klein', () {
      for (var i = 0; i < kWalkingLoopFrames; i++) {
        final a = sneakerPose(i / kWalkingLoopFrames);
        final b = sneakerPose((i + 1) / kWalkingLoopFrames);
        expect((a.x - b.x).abs(), lessThan(kStride / 10), reason: 'beeld $i');
        expect((a.lift - b.lift).abs(), lessThan(0.25), reason: 'beeld $i');
        expect((a.pitchDegrees - b.pitchDegrees).abs(), lessThan(5), reason: 'beeld $i');
      }
    });

    test('steunfase: op de grond en naar achter schuivend', () {
      final begin = sneakerPose(0);
      final midden = sneakerPose(kStance / 2);
      expect(begin.lift, 0);
      expect(midden.lift, 0);
      expect(midden.x, lessThan(begin.x));
      expect(begin.pitchDegrees, 0, reason: 'plat neergezet');
    });

    test('op het einde van de steunfase komt de hiel los (neus omlaag)', () {
      expect(sneakerPose(kStance - 0.01).pitchDegrees, greaterThan(10));
    });

    test('zwaaifase: omhoog en naar voren, landt plat', () {
      const midden = kStance + (1 - kStance) / 2;
      expect(sneakerPose(midden).lift, closeTo(1, 1e-9));
      expect(sneakerPose(midden).x, greaterThan(sneakerPose(kStance).x));
      expect(sneakerPose(0.9).pitchDegrees, lessThan(0), reason: 'neus omhoog vlak voor landen');
    });

    test('blijft binnen de pas', () {
      for (var i = 0; i < 200; i++) {
        final pose = sneakerPose(i / 200);
        expect(pose.x.abs(), lessThanOrEqualTo(kStride / 2 + 1e-9));
        expect(pose.lift, inInclusiveRange(0, 1));
      }
    });
  });

  group('sneakerBottom', () {
    test('plat: de hiel is het laagste punt, op halve hoogte onder het midden', () {
      expect(sneakerBottom(0, 100, 50), closeTo(25, 1e-9));
    });

    test('neus omlaag: de neus zakt onder het midden van een platte schoen', () {
      expect(sneakerBottom(16, 100, 50), greaterThan(25));
    });

    test('neus omhoog: de hiel zakt onder het midden van een platte schoen', () {
      expect(sneakerBottom(-9, 100, 50), greaterThan(25));
    });
  });

  test('smoothStep begint en eindigt zacht en blijft binnen 0..1', () {
    expect(smoothStep(-1), 0);
    expect(smoothStep(0), 0);
    expect(smoothStep(0.5), 0.5);
    expect(smoothStep(1), 1);
    expect(smoothStep(2), 1);
  });
}
