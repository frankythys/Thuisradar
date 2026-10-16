import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:thuisradar/features/map/domain/marker_nudge.dart';

void main() {
  const car = Rect.fromLTWH(100, 100, 100, 60);

  test('niets in de buurt: blijft op zijn plek', () {
    expect(nudgeClear(car, [const Rect.fromLTWH(400, 400, 40, 40)]), Offset.zero);
  });

  test('raakt een obstakel: schuift naar de kortste vrije kant', () {
    // Obstakel links in de autopin: naar rechts is korter dan naar links.
    final shift = nudgeClear(car, [const Rect.fromLTWH(90, 110, 40, 40)], gap: 0);
    expect(shift, const Offset(30, 0));
    expect(car.shift(shift).overlaps(const Rect.fromLTWH(90, 110, 40, 40)), isFalse);
  });

  test('obstakel rechts: schuift naar links', () {
    final shift = nudgeClear(car, [const Rect.fromLTWH(180, 110, 40, 40)], gap: 0);
    expect(shift, const Offset(-20, 0));
  });

  test('breed obstakel erboven (huis + persoon): schuift omlaag', () {
    final shift = nudgeClear(car, [const Rect.fromLTWH(0, 40, 300, 80)], gap: 0);
    expect(shift, const Offset(0, 20));
  });

  test('meerdere obstakels naast elkaar: duwt voorbij allemaal', () {
    final obstacles = [
      const Rect.fromLTWH(150, 100, 40, 40),
      const Rect.fromLTWH(195, 100, 40, 40),
      const Rect.fromLTWH(60, 100, 60, 40),
    ];
    final shift = nudgeClear(car, obstacles, gap: 0);
    final moved = car.shift(shift);
    expect(obstacles.any(moved.overlaps), isFalse);
  });

  test('marge houdt een kleine tussenruimte vrij', () {
    final shift = nudgeClear(car, [const Rect.fromLTWH(198, 110, 40, 40)]);
    expect(shift.dx, lessThan(0));
    expect(car.shift(shift).right, lessThanOrEqualTo(198 - 4));
  });

  test('geeft hele pixels, naar buiten afgerond', () {
    const obstacle = Rect.fromLTWH(90.3, 110, 40, 40);
    final shift = nudgeClear(car, [obstacle], gap: 0);
    expect(shift, const Offset(31, 0));
    expect(car.shift(shift).overlaps(obstacle), isFalse);
  });
}
