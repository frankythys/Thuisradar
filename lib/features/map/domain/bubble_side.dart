import 'dart:ui';

/// Aan welke kant van de avatar de statusballon komt te staan.
enum BubbleSide { left, right }

/// Kiest de kant waar de ballon vrij is. Standaard rechts; alleen als er rechts
/// een ander lid binnen [width] (en in dezelfde hoogteband [band]) staat én links
/// niet, springt de ballon naar links. Zo komt hij nooit over een andere naam.
/// Puur en in schermpixels, zodat het bij elke zoom opnieuw klopt.
BubbleSide chooseBubbleSide(Offset self, Iterable<Offset> others, {double width = 142, double band = 60}) {
  bool blocked(int sign) => others.any((other) {
    final dx = (other.dx - self.dx) * sign;
    return dx > 0 && dx <= width && (other.dy - self.dy).abs() <= band;
  });

  return blocked(1) && !blocked(-1) ? BubbleSide.left : BubbleSide.right;
}
