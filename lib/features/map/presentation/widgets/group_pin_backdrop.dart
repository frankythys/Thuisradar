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
    this.tip = 0,
    this.shadows = const [],
  });

  /// Linkerbovenhoek van elke cirkel (inclusief een eventuele "+N").
  final List<Offset> origins;
  final double diameter;

  /// Afstand tussen de middelpunten van buren; die krijgen een hals.
  final double step;

  /// Hoe ver het puntje onderaan, in het midden, onder de cirkels uitsteekt.
  final double tip;
  final Color color;
  final List<BoxShadow> shadows;

  @override
  Widget build(BuildContext context) => CustomPaint(
    size: Size(
      origins.fold(0.0, (width, origin) => math.max(width, origin.dx)) + diameter,
      origins.fold(0.0, (height, origin) => math.max(height, origin.dy)) + diameter + tip,
    ),
    painter: _BackdropPainter(
      origins: origins,
      diameter: diameter,
      step: step,
      tip: tip,
      color: color,
      shadows: shadows,
    ),
  );
}

class _BackdropPainter extends CustomPainter {
  _BackdropPainter({
    required this.origins,
    required this.diameter,
    required this.step,
    required this.tip,
    required this.color,
    required this.shadows,
  });

  final List<Offset> origins;
  final double diameter;
  final double step;
  final double tip;
  final Color color;
  final List<BoxShadow> shadows;

  /// Halve breedte van het puntje waar het uit de cirkels komt, als deel van
  /// de straal (±1/3 van een cirkel breed).
  static const _tipWidth = 0.4;

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
    if (tip > 0 && centers.isNotEmpty) path = Path.combine(PathOperation.union, path, _tipShape(centers, radius));
    return path;
  }

  /// Puntje onder het midden van de onderste rij; de rijen staan gecentreerd,
  /// dus het midden van de groep is het midden. Staan daar twee cirkels naast
  /// elkaar, dan loopt het vanaf de onderkant van allebei naar de punt en vult
  /// het de inkeping ertussen; anders vanaf de onderkant van de middelste.
  Path _tipShape(List<Offset> centers, double radius) {
    final xs = centers.map((center) => center.dx);
    final midX = (xs.reduce(math.min) + xs.reduce(math.max)) / 2;
    final baseY = centers.map((center) => center.dy).reduce(math.max);
    final bottomRow = centers.where((center) => (center.dy - baseY).abs() < 0.5).length;
    final half = radius * _tipWidth;
    // Hoeken net binnen de onderkant van de dichtste cirkel, dus geen naad.
    final toCircle = bottomRow.isEven ? step / 2 - half : half;
    final depth = math.sqrt(radius * radius - toCircle * toCircle) - 1;
    return Path()..addPolygon([
      Offset(midX - half, baseY),
      Offset(midX + half, baseY),
      Offset(midX + half, baseY + depth),
      Offset(midX, baseY + radius + tip),
      Offset(midX - half, baseY + depth),
    ], true);
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
      old.tip != tip ||
      old.color != color ||
      old.shadows != shadows;
}
