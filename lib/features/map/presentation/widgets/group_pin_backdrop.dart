import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

/// Eén witte vorm achter alle cirkels van een groepspin: cirkels die door een
/// "hals" verbonden zijn, zodat de witte randen in elkaar overvloeien in
/// plaats van losse ringen te tonen. De schaduw valt onder de hele vorm.
class GroupPinBackdrop extends StatelessWidget {
  const GroupPinBackdrop({
    super.key,
    required this.origins,
    required this.diameter,
    required this.step,
    required this.color,
    this.shadows = const [],
  });

  /// Linkerbovenhoek van elke cirkel (inclusief een eventuele "+N").
  final List<Offset> origins;
  final double diameter;

  /// Afstand tussen de middelpunten van buren; die krijgen een hals.
  final double step;
  final Color color;
  final List<BoxShadow> shadows;

  @override
  Widget build(BuildContext context) => CustomPaint(
    size: Size(
      origins.fold(0.0, (width, origin) => math.max(width, origin.dx)) + diameter,
      origins.fold(0.0, (height, origin) => math.max(height, origin.dy)) + diameter,
    ),
    painter: _BackdropPainter(origins: origins, diameter: diameter, step: step, color: color, shadows: shadows),
  );
}

class _BackdropPainter extends CustomPainter {
  _BackdropPainter({
    required this.origins,
    required this.diameter,
    required this.step,
    required this.color,
    required this.shadows,
  });

  final List<Offset> origins;
  final double diameter;
  final double step;
  final Color color;
  final List<BoxShadow> shadows;

  /// Breedte van de verbinding tussen twee cirkels, als deel van de diameter.
  static const _neck = 0.72;

  Path _shape() {
    final radius = diameter / 2;
    final centers = [for (final origin in origins) origin + Offset(radius, radius)];
    var path = Path();
    for (final (i, center) in centers.indexed) {
      path = Path.combine(
        PathOperation.union,
        path,
        Path()..addOval(Rect.fromCircle(center: center, radius: radius)),
      );
      // Hals naar elke buur, ook schuin naar de rij erboven. De uiteinden
      // liggen binnen de cirkels, dus een rechthoek volstaat.
      for (final other in centers.take(i)) {
        final along = center - other;
        if (along.distance > step + 1) continue;
        final across = Offset(-along.dy, along.dx) / along.distance * (radius * _neck);
        path = Path.combine(
          PathOperation.union,
          path,
          Path()..addPolygon([other + across, center + across, center - across, other - across], true),
        );
      }
    }
    return path;
  }

  @override
  void paint(Canvas canvas, Size size) {
    if (origins.isEmpty) return;
    final shape = _shape();
    for (final shadow in shadows) {
      final paint = shadow.toPaint();
      canvas.drawPath(shape.shift(shadow.offset), paint);
    }
    canvas.drawPath(shape, Paint()..color = color);
  }

  @override
  bool shouldRepaint(_BackdropPainter old) =>
      !listEquals(old.origins, origins) ||
      old.diameter != diameter ||
      old.step != step ||
      old.color != color ||
      old.shadows != shadows;
}
