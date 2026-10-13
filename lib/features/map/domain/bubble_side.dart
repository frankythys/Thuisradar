import 'dart:ui';

/// Aan welke kant van de avatar de statusballon komt te staan.
enum BubbleSide { left, right }

/// Kiest de kant waar de ballon vrij is. Standaard rechts; alleen als er rechts
/// een ander lid binnen [width] (en in dezelfde hoogteband [band]) staat én links
/// niet, springt de ballon naar links. Zo komt hij nooit over een andere naam.
/// Puur en in schermpixels, zodat het bij elke zoom opnieuw klopt.
///
/// [previous]: de kant van de vorige berekening. Staat de ballon al links, dan
/// gaat hij pas terug naar rechts als rechts ruim vrij is ([margin] extra), of
/// als links ook bezet raakt; zo wipt hij rond de grens niet heen en weer.
BubbleSide chooseBubbleSide(
  Offset self,
  Iterable<Offset> others, {
  double width = 142,
  double band = 60,
  BubbleSide? previous,
  double margin = 24,
}) {
  bool blocked(int sign, {double extra = 0}) => others.any((other) {
    final dx = (other.dx - self.dx) * sign;
    return dx > 0 && dx <= width + extra && (other.dy - self.dy).abs() <= band + extra;
  });

  if (previous == BubbleSide.left) {
    return !blocked(1, extra: margin) || blocked(-1) ? BubbleSide.right : BubbleSide.left;
  }
  return blocked(1) && !blocked(-1) ? BubbleSide.left : BubbleSide.right;
}
