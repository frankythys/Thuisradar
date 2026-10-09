import 'package:flutter_test/flutter_test.dart';
import 'package:thuisradar/features/map/domain/marker_spread.dart';

void main() {
  test('ver uit elkaar: niets verschuift', () {
    final shift = spreadHorizontally(const [
      SpreadItem('a', Offset(0, 0), 32),
      SpreadItem('b', Offset(200, 0), 32),
    ]);
    expect(shift, {'a': 0.0, 'b': 0.0});
  });

  test('overlappend: ze schuiven naast elkaar, symmetrisch', () {
    final shift = spreadHorizontally(const [
      SpreadItem('a', Offset(100, 0), 32),
      SpreadItem('b', Offset(120, 10), 32),
    ]);
    final a = 100 + shift['a']!;
    final b = 120 + shift['b']!;
    expect(b - a, closeTo(70, 0.01));
    expect(shift['a']!, lessThan(0));
    expect(shift['b']!, greaterThan(0));
  });

  test('zelfde punt: de eerste gaat naar links', () {
    final shift = spreadHorizontally(const [
      SpreadItem('ik', Offset(50, 50), 32),
      SpreadItem('jij', Offset(50, 50), 32),
    ]);
    expect(shift['ik']!, lessThan(0));
    expect(shift['jij']!, greaterThan(0));
  });

  test('ver boven elkaar: geen botsing', () {
    final shift = spreadHorizontally(const [
      SpreadItem('a', Offset(0, 0), 32),
      SpreadItem('b', Offset(0, 100), 32),
    ]);
    expect(shift, {'a': 0.0, 'b': 0.0});
  });

  test('drie dicht bij elkaar: alle drie naast elkaar', () {
    const items = [
      SpreadItem('e', Offset(100, 10), 32),
      SpreadItem('p', Offset(115, 0), 32),
      SpreadItem('l', Offset(108, 20), 32),
    ];
    final shift = spreadHorizontally(items);
    final xs = [for (final i in items) i.center.dx + shift[i.id]!]..sort();
    expect(xs[1] - xs[0], greaterThanOrEqualTo(69.9));
    expect(xs[2] - xs[1], greaterThanOrEqualTo(69.9));
  });
}
