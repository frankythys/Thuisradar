import 'package:flutter/material.dart';

import '../../../../core/theme/app_tokens.dart';

/// Puntje onder het rondje dat naar de echte locatie wijst (zoals Life360).
class MarkerTail extends StatelessWidget {
  const MarkerTail({super.key, required this.color, required this.height});

  static const width = 18.0;

  /// Puntje loopt 4 punten de halo in, zodat het de stip echt raakt.
  static const overlap = 4.0;

  final Color color;
  final double height;

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      size: Size(width, height),
      painter: _TailPainter(color: color, shadow: context.tokens.shadowMarker.firstOrNull?.color),
    );
  }
}

class _TailPainter extends CustomPainter {
  const _TailPainter({required this.color, this.shadow});

  final Color color;
  final Color? shadow;

  @override
  void paint(Canvas canvas, Size size) {
    // Driehoek met afgeronde punt; boven iets breder zodat hij in het rondje
    // overloopt (geen naad).
    final path = Path()
      ..moveTo(0, -2)
      ..lineTo(size.width, -2)
      ..lineTo(size.width / 2 + 2, size.height - 2)
      ..quadraticBezierTo(size.width / 2, size.height, size.width / 2 - 2, size.height - 2)
      ..close();
    if (shadow case final shadow?) canvas.drawShadow(path, shadow, 2, false);
    canvas.drawPath(path, Paint()..color = color);
  }

  @override
  bool shouldRepaint(_TailPainter old) => old.color != color || old.shadow != shadow;
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
