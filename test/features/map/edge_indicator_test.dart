import 'dart:math' as math;
import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:thuisradar/features/map/domain/edge_indicator.dart';

void main() {
  const visible = Rect.fromLTWH(0, 0, 400, 800);
  const radius = 30.0;

  test('wie in beeld staat, krijgt geen pijl', () {
    expect(edgeIndicators({'a': const Offset(200, 400)}, visible, radius: radius), isEmpty);
  });

  test('lid rechts buiten beeld: pijl op de rechterrand, wijst naar rechts', () {
    final [arrow] = edgeIndicators({'a': const Offset(900, 400)}, visible, radius: radius);
    expect(arrow.id, 'a');
    expect(arrow.position.dx, closeTo(400 - radius, 0.01));
    expect(arrow.position.dy, closeTo(400, 0.01));
    expect(arrow.angle, closeTo(0, 0.01));
  });

  test('lid ver boven het scherm: pijl bovenaan, wijst omhoog', () {
    final [arrow] = edgeIndicators({'a': const Offset(200, -5000)}, visible, radius: radius);
    expect(arrow.position.dy, closeTo(radius, 0.01));
    expect(arrow.angle, closeTo(-math.pi / 2, 0.01));
  });

  test('schuin buiten beeld: de pijl ligt op de lijn van het midden naar het lid', () {
    final [arrow] = edgeIndicators({'a': const Offset(-1000, 1400)}, visible, radius: radius);
    const center = Offset(200, 400);
    final toMember = const Offset(-1000, 1400) - center;
    final toArrow = arrow.position - center;
    expect(toArrow.direction, closeTo(toMember.direction, 0.001));
    expect(visible.deflate(radius - 0.01).contains(arrow.position), isTrue);
  });

  test('twee leden in dezelfde richting: de pijlen overlappen niet', () {
    final arrows = edgeIndicators(
      {'a': const Offset(900, 400), 'b': const Offset(950, 410)},
      visible,
      radius: radius,
    );
    expect(arrows, hasLength(2));
    expect((arrows[0].position - arrows[1].position).distance, greaterThanOrEqualTo(2 * radius));
    expect(arrows[1].position.dx, closeTo(400 - radius, 0.01), reason: 'blijft op de rechterrand');
  });

  test('wie al een pijl had, houdt die tot hij echt in beeld is (geen flikkeren)', () {
    const justInside = Offset(395, 400);
    expect(edgeIndicators({'a': justInside}, visible, radius: radius), isEmpty, reason: 'nieuw: in beeld');
    final kept = edgeIndicators({'a': justInside}, visible, radius: radius, shown: {'a'}, hysteresis: 24);
    expect(kept, hasLength(1), reason: 'had al een pijl en is nog geen 24 px binnen');
    final gone = edgeIndicators({'a': const Offset(300, 400)}, visible, radius: radius, shown: {'a'}, hysteresis: 24);
    expect(gone, isEmpty);
  });

  test('een pijl op de knoppen schuift erboven', () {
    // Knoppen rechtsonder, zoals centreren/auto/kaarttype.
    const buttons = Rect.fromLTRB(330, 560, 400, 800);
    final [arrow] = edgeIndicators({'a': const Offset(900, 1400)}, visible, radius: radius, avoid: [buttons]);
    expect(arrow.position.dx, closeTo(400 - radius, 0.01), reason: 'blijft op de rechterrand');
    expect(arrow.position.dy, closeTo(buttons.top - radius, 0.01));
  });

  test('achter het onderpaneel telt als buiten beeld', () {
    const aboveSheet = Rect.fromLTWH(0, 0, 400, 500);
    final [arrow] = edgeIndicators({'a': const Offset(200, 650)}, aboveSheet, radius: radius);
    expect(arrow.position.dy, closeTo(500 - radius, 0.01));
  });
}
