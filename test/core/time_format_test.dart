import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:thuisradar/core/utils/time_format.dart';
import 'package:thuisradar/l10n/l10n.dart';

final _nl = lookupAppLocalizations(const Locale('nl'));

void main() {
  final now = DateTime(2026, 10, 2, 18, 5);

  group('formatSince', () {
    test('vandaag toont enkel de kloktijd', () {
      expect(formatSince(_nl, DateTime(2026, 10, 2, 13, 3), now: now), '13:03');
    });

    test('gisteren wordt benoemd', () {
      expect(formatSince(_nl, DateTime(2026, 10, 1, 16, 49), now: now), '16:49 gisteren');
    });

    test('ouder toont ook de datum', () {
      expect(formatSince(_nl, DateTime(2026, 9, 28, 14, 2), now: now), '14:02 op 28/09');
    });
  });

  group('formatRelative', () {
    test('minder dan een minuut is "zonet"', () {
      expect(formatRelative(_nl, now.subtract(const Duration(seconds: 40)), now: now), 'zonet');
    });

    test('minuten', () {
      expect(formatRelative(_nl, now.subtract(const Duration(minutes: 5)), now: now), '5 min geleden');
    });

    test('uren', () {
      expect(formatRelative(_nl, now.subtract(const Duration(hours: 3)), now: now), '3 u geleden');
    });

    test('ouder dan een dag toont de datum', () {
      expect(formatRelative(_nl, DateTime(2026, 9, 28, 9), now: now), 'op 28/09');
    });
  });

  test('dagkop: vandaag, gisteren, anders weekdag + datum', () {
    final today = DateTime(2026, 10, 9, 14);
    expect(formatDayLabel(_nl, DateTime(2026, 10, 9, 8), now: today), 'Vandaag');
    expect(formatDayLabel(_nl, DateTime(2026, 10, 8, 23), now: today), 'Gisteren');
    expect(formatDayLabel(_nl, DateTime(2026, 10, 5, 12), now: today), 'ma 5/10');
  });

  test('andere talen: eigen woorden en decimaalteken', () {
    final en = lookupAppLocalizations(const Locale('en'));
    final today = DateTime(2026, 10, 9, 14);
    expect(formatDayLabel(en, DateTime(2026, 10, 5, 12), now: today), 'Mon 5/10');
    expect(formatRelative(en, now.subtract(const Duration(minutes: 5)), now: now), '5 min ago');
    expect(formatDistance(en, 2400), '2.4 km');
    expect(formatDistance(_nl, 2400), '2,4 km');
  });
}
