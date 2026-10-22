import 'dart:math' as math;
import 'dart:ui';

/// Pijl aan de rand van de kaart voor een lid buiten beeld: waar hij staat en
/// in welke richting het lid is ([angle] in radialen, 0 = rechts, met de klok
/// mee zoals op het scherm).
typedef EdgeIndicator = ({String id, Offset position, double angle});

/// Voor elk punt buiten [visible]: een plek op de rand van [visible], op de
/// lijn van het midden naar dat punt, [radius] van de rand zodat de pijl er
/// volledig in past. Behoudt de volgorde van [points].
///
/// - Een punt met een [reach] (bv. de straal van zijn pin) telt als in beeld
///   zolang er nog iets van die pin zichtbaar is: de pijl komt pas als de pin
///   volledig weg is.
/// - Wie al een pijl had ([shown]), houdt die tot hij [hysteresis] ver in
///   beeld is: zo flikkert niets als iemand net op de rand staat.
/// - Een vlak van [avoid] (bv. de knoppen) telt als buiten beeld: wie erachter
///   staat, krijgt een pijl. Een pijl die erin valt, schuift langs de rand
///   tot erbuiten.
/// - Pijlen die elkaar zouden raken, schuiven langs de rand naar het midden
///   van die rand.
List<EdgeIndicator> edgeIndicators(
  Map<String, Offset> points,
  Rect visible, {
  required double radius,
  Set<String> shown = const {},
  double hysteresis = 0,
  List<Rect> avoid = const [],
  Map<String, double> reach = const {},
}) {
  final inner = visible.deflate(radius);
  if (inner.width <= 0 || inner.height <= 0) return const [];
  final center = inner.center;
  final placed = <EdgeIndicator>[];
  for (final MapEntry(key: id, value: point) in points.entries) {
    final keep = (shown.contains(id) ? hysteresis : 0.0) - (reach[id] ?? 0);
    final inView =
        visible.deflate(keep).contains(point) && !avoid.any((area) => area.inflate(keep).contains(point));
    if (inView) continue;
    final direction = point - center;
    final toSide = direction.dx == 0 ? double.infinity : inner.width / 2 / direction.dx.abs();
    final toTopOrBottom = direction.dy == 0 ? double.infinity : inner.height / 2 / direction.dy.abs();
    final onTopOrBottom = toTopOrBottom < toSide;
    var position = _outside(center + direction * math.min(toSide, toTopOrBottom), avoid, inner, radius, onTopOrBottom);

    // Elke stap schuift één pijlbreedte, altijd dezelfde kant op.
    final step = Offset(
      onTopOrBottom ? 2 * radius * _towards(position.dx, center.dx) : 0,
      onTopOrBottom ? 0 : 2 * radius * _towards(position.dy, center.dy),
    );
    for (var tries = 0; tries <= placed.length && _overlaps(position, placed, radius); tries++) {
      final next = position + step;
      position = Offset(next.dx.clamp(inner.left, inner.right), next.dy.clamp(inner.top, inner.bottom));
    }
    placed.add((id: id, position: position, angle: math.atan2(direction.dy, direction.dx)));
  }
  return placed;
}

/// Ligt de pijl in een vlak van [avoid], dan langs de rand ernaast: op een
/// zijrand erboven (of eronder als er boven geen plaats is), bovenaan of
/// onderaan ernaast.
Offset _outside(Offset position, List<Rect> avoid, Rect inner, double radius, bool onTopOrBottom) {
  for (final area in avoid) {
    if (!area.inflate(radius).contains(position)) continue;
    if (onTopOrBottom) {
      final left = area.left - radius;
      return Offset(left >= inner.left ? left : area.right + radius, position.dy);
    }
    final above = area.top - radius;
    return Offset(position.dx, above >= inner.top ? above : area.bottom + radius);
  }
  return position;
}

bool _overlaps(Offset position, List<EdgeIndicator> placed, double radius) =>
    placed.any((other) => (other.position - position).distance < 2 * radius);

/// -1 of 1: de kant van [value] naar [target]; in het midden naar rechts/onder.
double _towards(double value, double target) => value > target ? -1 : 1;
