import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:thuisradar/features/map/domain/bubble_layout.dart';
import 'package:thuisradar/features/map/domain/bubble_side.dart';

void main() {
  BubbleRequest req(String id, Offset anchor, {BubbleSide side = BubbleSide.right}) =>
      (id: id, anchor: anchor, preferred: side, baseDy: -78);

  Rect rectOf(BubbleRequest r, BubblePlacement p) => bubbleRect(r.anchor, p.side, r.baseDy + p.shiftY);

  test('één ballon blijft op zijn voorkeursplek', () {
    final placements = layoutBubbles([req('a', const Offset(100, 300))]);
    expect(placements['a']!.side, BubbleSide.right);
    expect(placements['a']!.shiftY, 0);
  });

  test('twee leden dicht bij elkaar: ballonnen overlappen nooit', () {
    // Zoals op de kaart: Franky en een tweede lid vlak boven-rechts van hem.
    final requests = [req('franky', const Offset(150, 235)), req('liam', const Offset(220, 190))];
    final placements = layoutBubbles(requests);
    final a = rectOf(requests[0], placements['franky']!);
    final b = rectOf(requests[1], placements['liam']!);
    expect(a.overlaps(b), isFalse);
  });

  test('vijf leden op één plek: alle ballonnen vrij van elkaar', () {
    final requests = [for (var i = 0; i < 5; i++) req('m$i', Offset(200 + i * 3.0, 300 + i * 2.0))];
    final placements = layoutBubbles(requests);
    final rects = [for (final r in requests) rectOf(r, placements[r.id]!)];
    for (var i = 0; i < rects.length; i++) {
      for (var j = i + 1; j < rects.length; j++) {
        expect(rects[i].overlaps(rects[j]), isFalse, reason: 'ballon $i en $j');
      }
    }
  });

  test('ver uit elkaar: niets verschuift', () {
    final placements = layoutBubbles([req('a', const Offset(50, 100)), req('b', const Offset(50, 600))]);
    expect(placements.values.every((p) => p.shiftY == 0 && p.side == BubbleSide.right), isTrue);
  });

  test('een ballon gaat niet over het gezicht van een ander lid', () {
    final r = req('franky', const Offset(150, 300));
    final face = bubbleRect(r.anchor, BubbleSide.right, r.baseDy).center & const Size(40, 40);
    final placements = layoutBubbles([r], avatars: {'liam': face, 'franky': Rect.zero});
    expect(rectOf(r, placements['franky']!).overlaps(face), isFalse);
  });
}
