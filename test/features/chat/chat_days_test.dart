import 'package:flutter_test/flutter_test.dart';
import 'package:thuisradar/features/chat/domain/chat_days.dart';

void main() {
  final now = DateTime(2026, 10, 9, 14);

  test('dagnaam: vandaag, gisteren, anders weekdag + datum', () {
    expect(chatDayLabel(DateTime(2026, 10, 9, 8), now: now), 'Vandaag');
    expect(chatDayLabel(DateTime(2026, 10, 8, 23), now: now), 'Gisteren');
    expect(chatDayLabel(DateTime(2026, 10, 5, 12), now: now), 'ma 5/10');
  });

  test('nieuwe dag enkel bij een andere kalenderdag', () {
    expect(startsNewChatDay(null, now), isTrue);
    expect(startsNewChatDay(DateTime(2026, 10, 9, 1), now), isFalse);
    expect(startsNewChatDay(DateTime(2026, 10, 8, 23, 59), now), isTrue);
  });
}
