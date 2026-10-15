import 'package:flutter_test/flutter_test.dart';
import 'package:thuisradar/features/chat/domain/chat_days.dart';

void main() {
  final now = DateTime(2026, 10, 9, 14);

  test('nieuwe dag enkel bij een andere kalenderdag', () {
    expect(startsNewChatDay(null, now), isTrue);
    expect(startsNewChatDay(DateTime(2026, 10, 9, 1), now), isFalse);
    expect(startsNewChatDay(DateTime(2026, 10, 8, 23, 59), now), isTrue);
  });
}
