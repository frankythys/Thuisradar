import 'package:flutter/material.dart';

/// Eén witte vorm achter alle cirkels van een groepspin: cirkels die door een
/// "hals" verbonden zijn, zodat de witte randen in elkaar overvloeien in
/// plaats van losse ringen te tonen. De schaduw valt onder de hele vorm.
class GroupPinBackdrop extends StatelessWidget {
  const GroupPinBackdrop({
    super.key,
    required this.count,
    required this.diameter,
    required this.step,
    required this.color,
    this.shadows = const [],
  });

  /// Aantal cirkels op één rij (inclusief een eventuele "+N").
  final int count;
  final double diameter;

  /// Horizontale afstand tussen de middelpunten.
  final double step;
  final Color color;
  final List<BoxShadow> shadows;

  @override
  Widget build(BuildContext context) => CustomPaint(
    size: Size((count - 1) * step + diameter, diameter),
    painter: _BackdropPainter(count: count, diameter: diameter, step: step, color: color, shadows: shadows),
  );
}

class _BackdropPainter extends CustomPainter {
  _BackdropPainter({
    required this.count,
    required this.diameter,
    required this.step,
    required this.color,
    required this.shadows,
  });

  final int count;
  final double diameter;
  final double step;
  final Color color;
  final List<BoxShadow> shadows;

  /// Hoogte van de verbinding tussen twee cirkels, als deel van de diameter.
  static const _neck = 0.9;

  Path _shape() {
    final radius = diameter / 2;
    var path = Path();
    for (var i = 0; i < count; i++) {
      final center = Offset(radius + i * step, radius);
      path = Path.combine(
        PathOperation.union,
        path,
        Path()..addOval(Rect.fromCircle(center: center, radius: radius)),
      );
      if (i == 0) continue;
      final neck = Rect.fromLTRB(
        radius + (i - 1) * step,
        radius * (1 - _neck),
        center.dx,
        radius * (1 + _neck),
      );
      path = Path.combine(
        PathOperation.union,
        path,
        Path()..addRRect(RRect.fromRectAndRadius(neck, Radius.circular(radius * _neck))),
      );
    }
    return path;
  }

  @override
  void paint(Canvas canvas, Size size) {
    if (count <= 0) return;
    final shape = _shape();
    for (final shadow in shadows) {
      final paint = shadow.toPaint();
      canvas.drawPath(shape.shift(shadow.offset), paint);
    }
    canvas.drawPath(shape, Paint()..color = color);
  }

  @override
  bool shouldRepaint(_BackdropPainter old) =>
      old.count != count ||
      old.diameter != diameter ||
      old.step != step ||
      old.color != color ||
      old.shadows != shadows;
}
