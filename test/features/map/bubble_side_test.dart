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
}
