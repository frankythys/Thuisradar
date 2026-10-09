import 'package:flutter_test/flutter_test.dart';
import 'package:thuisradar/core/utils/time_format.dart';

void main() {
  test('formatClock vult met nullen aan', () {
    expect(formatClock(DateTime(2026, 1, 2, 9, 5)), '09:05');
    expect(formatClock(DateTime(2026, 1, 2, 17, 42)), '17:42');
  });

  test('formatDuration toont uren en minuten in het Nederlands', () {
    expect(formatDuration(const Duration(minutes: 25)), '25 min');
    expect(formatDuration(const Duration(hours: 1)), '1 u');
    expect(formatDuration(const Duration(hours: 2, minutes: 15)), '2 u 15 min');
  });

  test('formatDistance gebruikt meters of kilometers met komma', () {
    expect(formatDistance(850), '850 m');
    expect(formatDistance(2400), '2,4 km');
  });

  test('dagkop: vandaag, gisteren en anders weekdag + datum', () {
    final now = DateTime(2026, 10, 9, 14);
    expect(formatDayLabel(DateTime(2026, 10, 9, 1), now: now), 'Vandaag');
    expect(formatDayLabel(DateTime(2026, 10, 8, 23), now: now), 'Gisteren');
    expect(formatDayLabel(DateTime(2026, 10, 5, 9), now: now), 'ma 5/10');
    expect(isOtherDay(DateTime(2026, 10, 8, 23, 59), now), isTrue);
    expect(isOtherDay(DateTime(2026, 10, 9), now), isFalse);
  });
}
