import 'dart:ui';

/// Kleinste verschuiving (in schermpixels) waarmee [marker] geen enkele van
/// de [obstacles] meer raakt: eerst naar rechts, links of omlaag, en daarvan
/// de kortste. Raakt hij niets, dan blijft hij op zijn plek (`Offset.zero`).
/// Puur en deterministisch; wordt bij elke zoom opnieuw berekend, zodat een
/// marker ingezoomd gewoon op zijn echte plek staat.
Offset nudgeClear(Rect marker, List<Rect> obstacles, {double gap = 4}) {
  bool hits(Rect rect) => obstacles.any((o) => rect.overlaps(o.inflate(gap)));
  if (!hits(marker)) return Offset.zero;

  Offset? best;
  for (final direction in const [Offset(1, 0), Offset(-1, 0), Offset(0, 1)]) {
    final shift = _push(marker, obstacles, direction, gap);
    if (shift == null) continue;
    if (best == null || shift.distance < best.distance) best = shift;
  }
  // Nergens vrij (zeer druk scherm): dan liever op de echte plek blijven.
  final result = best ?? Offset.zero;
  // Hele pixels (naar buiten afgerond, dus nooit terug in het obstakel):
  // Google hoeft de afbeelding niet bij elke fractie te hertekenen.
  return Offset(_outward(result.dx), _outward(result.dy));
}

double _outward(double value) => value.sign * value.abs().ceilToDouble();

/// Duwt [marker] stap voor stap in [direction] voorbij elk obstakel dat hij
/// raakt. Geeft null als hij na alle obstakels nog altijd iets raakt.
Offset? _push(Rect marker, List<Rect> obstacles, Offset direction, double gap) {
  var amount = 0.0;
  for (var pass = 0; pass <= obstacles.length; pass++) {
    final moved = marker.shift(direction * amount);
    final colliding = [
      for (final o in obstacles)
        if (moved.overlaps(o.inflate(gap))) o.inflate(gap),
    ];
    if (colliding.isEmpty) return direction * amount;
    for (final o in colliding) {
      final needed = switch (direction) {
        Offset(dx: > 0) => o.right - marker.left,
        Offset(dx: < 0) => marker.right - o.left,
        _ => o.bottom - marker.top,
      };
      if (needed > amount) amount = needed;
    }
  }
  return null;
}
