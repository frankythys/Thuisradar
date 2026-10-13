import 'package:flutter_test/flutter_test.dart';
import 'package:thuisradar/features/map/domain/bubble_side.dart';

void main() {
  const self = Offset(100, 100);

  test('zonder buren staat de ballon rechts', () {
    expect(chooseBubbleSide(self, const []), BubbleSide.right);
  });

  test('een lid vlak rechts duwt de ballon naar links', () {
    expect(chooseBubbleSide(self, const [Offset(160, 110)]), BubbleSide.left);
  });

  test('een lid links én rechts: blijft rechts (links is ook geblokkeerd)', () {
    expect(chooseBubbleSide(self, const [Offset(160, 100), Offset(40, 100)]), BubbleSide.right);
  });

  test('een lid rechts maar ver boven telt niet mee', () {
    expect(chooseBubbleSide(self, const [Offset(160, 200)]), BubbleSide.right);
  });

  test('een lid ver rechts (buiten ballonbreedte) telt niet mee', () {
    expect(chooseBubbleSide(self, const [Offset(300, 100)]), BubbleSide.right);
  });

  test('links blijft links tot rechts ruim vrij is (geen heen-en-weer rond de grens)', () {
    // Net buiten de ballonbreedte: zonder geheugen rechts, met geheugen links.
    const edge = [Offset(250, 100)];
    expect(chooseBubbleSide(self, edge), BubbleSide.right);
    expect(chooseBubbleSide(self, edge, previous: BubbleSide.left), BubbleSide.left);
    // Ruim vrij: terug naar rechts.
    expect(chooseBubbleSide(self, const [Offset(300, 100)], previous: BubbleSide.left), BubbleSide.right);
    // Links raakt ook bezet: standaard rechts.
    expect(
      chooseBubbleSide(self, const [Offset(250, 100), Offset(40, 100)], previous: BubbleSide.left),
      BubbleSide.right,
    );
  });
}
