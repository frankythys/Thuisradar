import 'package:flutter/material.dart';

import '../../../../core/theme/app_tokens.dart';

/// Puntje onder het rondje dat naar de echte locatie wijst (zoals Life360).
class MarkerTail extends StatelessWidget {
  const MarkerTail({super.key, required this.color, required this.height, required this.circleRadius});

  /// Breedte bovenaan, [inset] achter het rondje: de schuine kanten komen
  /// zo op ±16 punten van het midden uit het rondje (breed, zoals Life360).
  static const width = 40.0;

  /// Zo ver begint het puntje binnen het rondje, zodat er geen naad is.
  static const inset = 10.0;

  /// Puntje loopt 4 punten de halo in, zodat het de stip echt raakt.
  static const overlap = 4.0;

  final Color color;
  final double height;

  /// Straal van het rondje erboven: die vorm blijft uit het puntje, zodat het
  /// naadloos op de rand aansluit zonder het rondje te bedekken.
  final double circleRadius;

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      size: Size(width, height),
      painter: _TailPainter(
        color: color,
        circleRadius: circleRadius,
        shadow: context.tokens.shadowMarker.firstOrNull?.color,
      ),
    );
  }
}

class _TailPainter extends CustomPainter {
  const _TailPainter({required this.color, required this.circleRadius, this.shadow});

  final Color color;
  final double circleRadius;
  final Color? shadow;

  @override
  void paint(Canvas canvas, Size size) {
    // Driehoek met afgeronde punt; de bovenkant valt binnen het rondje en
    // wordt eruit geknipt.
    final triangle = Path()
      ..moveTo(0, 0)
      ..lineTo(size.width, 0)
      ..lineTo(size.width / 2 + 2, size.height - 2)
      ..quadraticBezierTo(size.width / 2, size.height, size.width / 2 - 2, size.height - 2)
      ..close();
    final circle = Path()
      ..addOval(
        Rect.fromCircle(
          center: Offset(size.width / 2, MarkerTail.inset - circleRadius),
          radius: circleRadius - 0.5,
        ),
      );
    final path = Path.combine(PathOperation.difference, triangle, circle);
    if (shadow case final shadow?) canvas.drawShadow(path, shadow, 2, false);
    canvas.drawPath(path, Paint()..color = color);
  }

  @override
  bool shouldRepaint(_TailPainter old) =>
      old.color != color || old.shadow != shadow || old.circleRadius != circleRadius;
}

/// Stip op de exacte locatie met een zachte halo eromheen.
class LocationDot extends StatelessWidget {
  const LocationDot({super.key, required this.color});

  /// Doorsnede van de halo; de stip zelf is kleiner.
  static const haloSize = 28.0;
  static const dotSize = 10.0;

  final Color color;

  @override
  Widget build(BuildContext context) {
    return SizedBox.square(
      dimension: haloSize,
      child: DecoratedBox(
        decoration: BoxDecoration(shape: BoxShape.circle, color: color.withValues(alpha: 0.2)),
        child: Center(
          child: Container(
            width: dotSize,
            height: dotSize,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: color,
              border: Border.all(color: Colors.white, width: 2),
            ),
          ),
        ),
      ),
    );
  }
}
