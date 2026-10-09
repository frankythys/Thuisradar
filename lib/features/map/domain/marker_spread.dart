import 'dart:ui';

/// Eén marker op het scherm: middelpunt (px) en halve breedte (px).
class SpreadItem {
  const SpreadItem(this.id, this.center, this.halfWidth);

  final String id;
  final Offset center;
  final double halfWidth;
}

/// Schuift markers die op het scherm over elkaar zouden vallen horizontaal
/// uit elkaar, zodat leden op aparte locaties naast elkaar staan i.p.v.
/// samen te vallen. Geeft per id de horizontale verschuiving in px (positief =
/// naar rechts). Puur en deterministisch; wordt bij elke zoom herberekend.
Map<String, double> spreadHorizontally(
  List<SpreadItem> items, {
  double gap = 6,
  double rowHeight = 64,
  int iterations = 16,
}) {
  final shift = {for (final item in items) item.id: 0.0};
  for (var round = 0; round < iterations; round++) {
    var moved = false;
    for (var i = 0; i < items.length; i++) {
      for (var j = i + 1; j < items.length; j++) {
        final a = items[i];
        final b = items[j];
        // Enkel buren op (ongeveer) dezelfde hoogte kunnen botsen.
        if ((a.center.dy - b.center.dy).abs() >= rowHeight) continue;
        final ax = a.center.dx + shift[a.id]!;
        final bx = b.center.dx + shift[b.id]!;
        final needed = a.halfWidth + b.halfWidth + gap;
        final distance = (bx - ax).abs();
        if (distance >= needed) continue;
        final push = (needed - distance) / 2;
        // Gelijke positie: het eerste (bv. "ik") gaat naar links.
        final direction = bx > ax || (bx == ax) ? 1.0 : -1.0;
        shift[a.id] = shift[a.id]! - direction * push;
        shift[b.id] = shift[b.id]! + direction * push;
        moved = true;
      }
    }
    if (!moved) break;
  }
  return shift;
}
