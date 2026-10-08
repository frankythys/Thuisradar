import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:thuisradar/features/map/domain/marker_clearance.dart';

void main() {
  test('groep laat het huis vrij bij elke schermschaal', () {
    for (final point in [const Offset(100, 100), const Offset(400, 600)]) {
      final bounds = Rect.fromLTWH(point.dx - 130, point.dy - 160, 260, 160);
      final shifted = bounds.shift(markerClearance(bounds, [point]));
      expect(
        shifted.overlaps(Rect.fromCircle(center: point, radius: 16)),
        isFalse,
      );
      expect(shifted.bottom, lessThanOrEqualTo(point.dy - 24));
    }
  });
  test('geen overlap behoudt de oorspronkelijke positie', () {
    expect(
      markerClearance(const Rect.fromLTWH(0, 0, 120, 96), [
        const Offset(300, 300),
      ]),
      Offset.zero,
    );
  });
  test('een losse avatar blijft vrij van het huis', () {
    const bounds = Rect.fromLTWH(40, 100, 120, 96);
    const home = Offset(100, 100);
    final shifted = bounds.shift(markerClearance(bounds, [home]));
    expect(shifted.bottom, lessThanOrEqualTo(home.dy - 24));
  });
}
