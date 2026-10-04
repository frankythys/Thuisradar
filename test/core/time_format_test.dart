import 'package:flutter_test/flutter_test.dart';
import 'package:thuisradar/core/utils/time_format.dart';

void main() {
  final now = DateTime(2026, 10, 2, 18, 5);

  group('formatSince', () {
    test('vandaag toont enkel de kloktijd', () {
      expect(formatSince(DateTime(2026, 10, 2, 13, 3), now: now), '13:03');
    });

    test('gisteren wordt benoemd', () {
      expect(formatSince(DateTime(2026, 10, 1, 16, 49), now: now), '16:49 gisteren');
    });

    test('ouder toont ook de datum', () {
      expect(formatSince(DateTime(2026, 9, 28, 14, 2), now: now), '14:02 op 28/09');
    });
  });

  group('formatRelative', () {
    test('minder dan een minuut is "zonet"', () {
      expect(formatRelative(now.subtract(const Duration(seconds: 40)), now: now), 'zonet');
    });

    test('minuten', () {
      expect(formatRelative(now.subtract(const Duration(minutes: 5)), now: now), '5 min geleden');
    });

    test('uren', () {
      expect(formatRelative(now.subtract(const Duration(hours: 3)), now: now), '3 u geleden');
    });

    test('ouder dan een dag toont de datum', () {
      expect(formatRelative(DateTime(2026, 9, 28, 9), now: now), 'op 28/09');
    });
  });
}
