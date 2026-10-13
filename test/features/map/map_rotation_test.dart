import 'package:flutter_test/flutter_test.dart';
import 'package:thuisradar/features/map/domain/map_rotation.dart';

void main() {
  test('terug naar het noorden neemt de korte weg', () {
    expect(normalizedRotation(0), 0);
    expect(normalizedRotation(45), 45);
    expect(normalizedRotation(350), -10);
    expect(normalizedRotation(-350), 10);
    expect(normalizedRotation(180), 180);
    expect(normalizedRotation(720 + 30), 30);
  });

  test('pas gedraaid vanaf een zichtbare afwijking', () {
    expect(isRotated(0), isFalse);
    expect(isRotated(0.2), isFalse);
    expect(isRotated(359.8), isFalse);
    expect(isRotated(5), isTrue);
    expect(isRotated(355), isTrue);
  });
}
