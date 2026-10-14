import 'package:flutter_test/flutter_test.dart';
import 'package:thuisradar/features/map/domain/sheet_snap.dart';

void main() {
  const peek = 0.04;
  const rest = 0.2;

  test('onder de helft tussen laag en gewoon: helemaal laag', () {
    expect(sheetSnapTarget(0.08, peek: peek, rest: rest), peek);
  });

  test('boven de helft: terug naar de gewone stand', () {
    expect(sheetSnapTarget(0.15, peek: peek, rest: rest), rest);
  });

  test('al op een stand of erboven: niets doen (vrij slepen)', () {
    expect(sheetSnapTarget(peek, peek: peek, rest: rest), isNull);
    expect(sheetSnapTarget(rest, peek: peek, rest: rest), isNull);
    expect(sheetSnapTarget(0.6, peek: peek, rest: rest), isNull);
  });

  test('geen ruimte tussen de standen: niets doen', () {
    expect(sheetSnapTarget(0.1, peek: 0.2, rest: 0.2), isNull);
  });
}
