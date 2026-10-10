import 'package:flutter/material.dart';

/// Dun kruis met een stipje: het midden is exact het punt dat bewaard wordt.
/// Een wit randje houdt het zichtbaar op elke kaart.
class PlaceCrosshair extends StatelessWidget {
  const PlaceCrosshair({super.key});

  static const size = 44.0;

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: CustomPaint(
        size: const Size.square(size),
        painter: _CrosshairPainter(Theme.of(context).colorScheme.primary),
      ),
    );
  }
}

class _CrosshairPainter extends CustomPainter {
  const _CrosshairPainter(this.color);

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final c = size.center(Offset.zero);
    final arm = size.width / 2;
    // Opening in het midden, zodat het stipje vrij blijft.
    const gap = 5.0;
    void lines(Paint paint) {
      canvas
        ..drawLine(c.translate(-arm, 0), c.translate(-gap, 0), paint)
        ..drawLine(c.translate(gap, 0), c.translate(arm, 0), paint)
        ..drawLine(c.translate(0, -arm), c.translate(0, -gap), paint)
        ..drawLine(c.translate(0, gap), c.translate(0, arm), paint);
    }

    lines(
      Paint()
        ..color = Colors.white
        ..strokeWidth = 4
        ..strokeCap = StrokeCap.round,
    );
    lines(
      Paint()
        ..color = color
        ..strokeWidth = 2
        ..strokeCap = StrokeCap.round,
    );
    canvas
      ..drawCircle(c, 3.5, Paint()..color = Colors.white)
      ..drawCircle(c, 2.5, Paint()..color = color);
  }

  @override
  bool shouldRepaint(_CrosshairPainter old) => old.color != color;
}
