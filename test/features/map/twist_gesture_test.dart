import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:thuisradar/features/map/domain/twist_gesture.dart';

TouchPoint _around(double degrees, {required bool left}) {
  final angle = degrees * math.pi / 180;
  final sign = left ? -1 : 1;
  return (x: 400 + sign * 150 * math.cos(angle), y: 300 + sign * 150 * math.sin(angle));
}

void main() {
  test('draaihoek is genormaliseerd, ongeacht welke vinger eerst kwam', () {
    // Linker vinger eerst: Flutter zou hier -359° geven voor +1°.
    expect(
      twistDegrees(
        _around(0, left: true),
        _around(0, left: false),
        _around(1, left: true),
        _around(1, left: false),
      ),
      closeTo(1, 1e-9),
    );
    expect(
      twistDegrees(
        _around(0, left: false),
        _around(0, left: true),
        _around(-1, left: false),
        _around(-1, left: true),
      ),
      closeTo(-1, 1e-9),
    );
  });

  void twist(TwistGesture gesture, double degrees, {required bool leftFirst}) {
    gesture
      ..down(1, _around(0, left: leftFirst))
      ..down(2, _around(0, left: !leftFirst));
    for (var step = 1; step <= 10; step++) {
      final angle = degrees * step / 10;
      gesture
        ..move(1, _around(angle, left: leftFirst))
        ..move(2, _around(angle, left: !leftFirst));
    }
  }

  for (final leftFirst in [true, false]) {
    final order = leftFirst ? 'linker' : 'rechter';
    test('$order vinger eerst: kleine draai blijft knijpen, duidelijke draai draait', () {
      final small = TwistGesture();
      twist(small, 20, leftFirst: leftFirst);
      expect(small.rotating, isFalse);

      final clockwise = TwistGesture();
      twist(clockwise, 35, leftFirst: leftFirst);
      expect(clockwise.rotating, isTrue);

      final counter = TwistGesture();
      twist(counter, -35, leftFirst: leftFirst);
      expect(counter.rotating, isTrue);
    });
  }

  test('draaien blijft aan tot alle vingers los zijn, daarna begint het opnieuw', () {
    final gesture = TwistGesture();
    twist(gesture, 40, leftFirst: true);
    gesture.up(1);
    expect(gesture.rotating, isTrue);
    gesture.up(2);
    expect(gesture.rotating, isFalse);

    twist(gesture, 5, leftFirst: true);
    expect(gesture.rotating, isFalse);
  });

  test('eerst zoomen: daarna meedraaien zet de kaart niet scheef', () {
    final gesture = TwistGesture()
      ..down(1, (x: 300, y: 300))
      ..down(2, (x: 500, y: 300));
    // Vingers 30% uit elkaar: zoomen.
    gesture
      ..move(1, (x: 270, y: 300))
      ..move(2, (x: 530, y: 300));
    expect(gesture.rotating, isFalse);
    // Nu flink draaien in hetzelfde gebaar.
    gesture
      ..move(1, (x: 300, y: 450))
      ..move(2, (x: 500, y: 150));
    expect(gesture.rotating, isFalse);
  });

  test('één vinger slepen draait nooit', () {
    final gesture = TwistGesture()..down(1, (x: 100, y: 100));
    gesture.move(1, (x: 300, y: 400));
    expect(gesture.rotating, isFalse);
  });
}
