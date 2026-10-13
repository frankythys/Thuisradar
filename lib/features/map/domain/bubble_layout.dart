import 'dart:ui';

import 'bubble_side.dart';

/// Afmetingen van een statusballon op de kaart (schermpixels).
const kBubbleWidth = 142.0;
const kBubbleHeight = 48.0;

/// Horizontale afstand tussen de ankerpositie van een lid en zijn ballon.
const kBubbleInset = 20.0;

/// Waar een ballon komt: links of rechts van het lid, en hoeveel hoger (min)
/// of lager (plus) dan zijn standaardhoogte.
class BubblePlacement {
  const BubblePlacement(this.side, this.shiftY);

  final BubbleSide side;
  final double shiftY;

  @override
  bool operator ==(Object other) => other is BubblePlacement && other.side == side && other.shiftY == shiftY;

  @override
  int get hashCode => Object.hash(side, shiftY);
}

/// Eén ballon die geplaatst moet worden.
typedef BubbleRequest = ({String id, Offset anchor, BubbleSide preferred, double baseDy});

/// Het scherm-rechthoek van een ballon, zoals de kaart hem tekent.
Rect bubbleRect(Offset anchor, BubbleSide side, double dy) {
  final left = side == BubbleSide.right ? anchor.dx + kBubbleInset : anchor.dx - kBubbleInset - kBubbleWidth;
  return Rect.fromLTWH(left, anchor.dy + dy, kBubbleWidth, kBubbleHeight);
}

/// Plaatst alle ballonnen zodat ze nooit over elkaar vallen, en zo mogelijk
/// ook niet over het gezicht van een ander lid ([avatars], zelfde
/// coördinaten als [bubbleRect]). Van boven naar
/// onder krijgt elk lid de eerste vrije plek: eerst zijn voorkeurskant, dan de
/// andere kant, daarna telkens een rij hoger of lager. Puur en in
/// schermpixels, dus bij elke zoom opnieuw juist.
///
/// [previous]: de plaatsing van de vorige berekening. Een ballon die al
/// uitweek, blijft op zijn plek zolang die (met [slack] speling) vrij blijft,
/// en keert pas terug naar zijn gewone plek als die ruim vrij is. Zo springt
/// hij niet heen en weer terwijl leden bewegen of de kaart zoomt.
Map<String, BubblePlacement> layoutBubbles(
  List<BubbleRequest> requests, {
  Map<String, Rect> avatars = const {},
  double gap = 6,
  Map<String, BubblePlacement> previous = const {},
  double slack = 8,
}) {
  final ordered = [...requests]
    ..sort((a, b) {
      final byY = a.anchor.dy.compareTo(b.anchor.dy);
      return byY != 0 ? byY : a.id.compareTo(b.id);
    });
  final placed = <Rect>[];
  final result = <String, BubblePlacement>{};
  const rows = [0, -1, 1, -2, 2, -3, 3];
  for (final request in ordered) {
    final other = request.preferred == BubbleSide.right ? BubbleSide.left : BubbleSide.right;
    // Een gezicht dat over het eigen gezicht ligt (zelfde plek), valt toch
    // niet te ontwijken en telt niet mee.
    final own = avatars[request.id];
    final faces = [
      for (final entry in avatars.entries)
        if (entry.key != request.id && (own == null || !own.overlaps(entry.value))) entry.value,
    ];
    // [extra] > 0 is strenger (ruim vrij), < 0 milder (mag net raken).
    bool free(Rect rect, {required bool avoidFaces, double extra = 0}) =>
        placed.every((p) => !p.inflate(gap / 2 + extra).overlaps(rect)) &&
        (!avoidFaces || faces.every((f) => !f.inflate(extra).overlaps(rect)));
    BubblePlacement? chosen;
    Rect? chosenRect;
    final last = previous[request.id];
    final home = BubblePlacement(request.preferred, 0);
    if (last != null && last != home) {
      final homeRect = bubbleRect(request.anchor, home.side, request.baseDy);
      final lastRect = bubbleRect(request.anchor, last.side, request.baseDy + last.shiftY);
      if (free(homeRect, avoidFaces: true, extra: slack)) {
        (chosen, chosenRect) = (home, homeRect);
      } else if (free(lastRect, avoidFaces: true, extra: -slack)) {
        (chosen, chosenRect) = (last, lastRect);
      }
    } else if (last != null) {
      final homeRect = bubbleRect(request.anchor, home.side, request.baseDy);
      if (free(homeRect, avoidFaces: true, extra: -slack)) (chosen, chosenRect) = (home, homeRect);
    }
    // Eerst een plek vrij van ballonnen én gezichten van anderen; lukt dat
    // nergens, dan minstens vrij van andere ballonnen.
    for (final avoidFaces in [true, false]) {
      if (chosen != null) break;
      for (final row in rows) {
        final shift = row * (kBubbleHeight + gap);
        for (final side in [request.preferred, other]) {
          final rect = bubbleRect(request.anchor, side, request.baseDy + shift);
          if (free(rect, avoidFaces: avoidFaces)) {
            chosen = BubblePlacement(side, shift);
            chosenRect = rect;
            break;
          }
        }
        if (chosen != null) break;
      }
    }
    chosen ??= BubblePlacement(request.preferred, 0);
    chosenRect ??= bubbleRect(request.anchor, request.preferred, request.baseDy);
    placed.add(chosenRect);
    result[request.id] = chosen;
  }
  return result;
}
