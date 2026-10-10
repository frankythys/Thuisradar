import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:thuisradar/features/map/domain/native_marker_frame.dart';

void main() {
  test('rijdende auto: gecentreerd op het punt', () {
    final frame = nativeMarkerFrame(size: const Size(60, 60));
    expect(frame.canvas, const Size(60, 60));
    expect(frame.anchor, const Offset(0.5, 0.5));
  });

  test('stilstaand lid: pin boven het punt, punt onderaan midden', () {
    final frame = nativeMarkerFrame(size: const Size(60, 80), alignY: -1);
    expect(frame.canvas, const Size(60, 80));
    expect(frame.child, const Rect.fromLTWH(0, 0, 60, 80));
    expect(frame.anchor, const Offset(0.5, 1));
  });

  test('ballon rechtsboven met verschuiving: canvas omvat ballon én punt', () {
    // Zoals de statusballon: rechts van het punt, verschoven naar boven.
    final frame = nativeMarkerFrame(
      size: const Size(142, 48),
      alignX: 1,
      alignY: -1,
      offset: const Offset(10, -78),
    );
    // Ballon loopt van x 10..152 en y -126..-78 rond het punt (0,0).
    expect(frame.canvas, const Size(152, 126));
    expect(frame.child, const Rect.fromLTWH(10, 0, 142, 48));
    expect(frame.anchor.dx, closeTo(0, 1e-9));
    expect(frame.anchor.dy, closeTo(1, 1e-9));
  });

  test('ballon links: punt rechts in het canvas', () {
    final frame = nativeMarkerFrame(
      size: const Size(142, 48),
      alignX: -1,
      alignY: -1,
      offset: const Offset(-10, -78),
    );
    expect(frame.anchor.dx, closeTo(1, 1e-9));
    expect(frame.child.left, 0);
  });

  test('marge: ruimte voor gloed en lichtkring rond het geselecteerde lid', () {
    final frame = nativeMarkerFrame(size: const Size(60, 80), alignY: -1, margin: 20);
    expect(frame.canvas, const Size(100, 120));
    expect(frame.child, const Rect.fromLTWH(20, 20, 60, 80));
    expect(frame.anchor.dx, closeTo(0.5, 1e-9));
    expect(frame.anchor.dy, closeTo(100 / 120, 1e-9));
  });
}
