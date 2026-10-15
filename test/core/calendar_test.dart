import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:thuisradar/l10n/l10n.dart';
import 'package:thuisradar/core/utils/calendar.dart';
import 'package:thuisradar/core/utils/time_format.dart';
import 'package:thuisradar/features/driving/presentation/driving_summary.dart';

final _nl = lookupAppLocalizations(const Locale('nl'));

void main() {
  test('kalenderdagen tellen ook over de zomertijd- en wintertijdovergang', () {
    expect(calendarDaysBetween(DateTime(2026, 3, 28, 23), DateTime(2026, 3, 30, 0, 30)), 2);
    expect(calendarDaysBetween(DateTime(2026, 3, 29), DateTime(2026, 3, 30)), 1);
    expect(calendarDaysBetween(DateTime(2026, 10, 25), DateTime(2026, 10, 26)), 1);
    expect(calendarDaysBetween(DateTime(2026, 10, 26), DateTime(2026, 10, 25)), -1);
  });

  test('daglabels kloppen de dag na de overgang naar zomertijd', () {
    final now = DateTime(2026, 3, 30, 9);
    expect(formatDayLabel(_nl, DateTime(2026, 3, 29, 20), now: now), 'Gisteren');
    expect(drivingDayLabel(DateTime(2026, 3, 29), now: now), 'Gisteren');
    expect(formatDayLabel(_nl, DateTime(2026, 3, 28, 20), now: now), isNot('Gisteren'));
  });
}
