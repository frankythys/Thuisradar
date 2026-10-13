import 'package:flutter_test/flutter_test.dart';
import 'package:thuisradar/features/location/domain/member_location.dart';
import 'package:thuisradar/features/location/domain/pending_uploads.dart';

void main() {
  final start = DateTime(2026, 10, 13, 19, 48);
  MemberLocation at(int seconds) => MemberLocation(
    userId: 'p',
    familyId: 'f',
    latitude: 51,
    longitude: 3,
    updatedAt: start.add(Duration(seconds: seconds)),
  );

  test('oudste eerst, ook als punten in de verkeerde volgorde binnenkomen', () {
    final queue = PendingUploads()
      ..add(at(10))
      ..add(at(0))
      ..add(at(5))
      ..add(at(5));
    expect(queue.length, 3);
    expect(queue.next!.updatedAt, start);
    queue.sent();
    expect(queue.next!.updatedAt, start.add(const Duration(seconds: 5)));
  });

  test('zonder netwerk steeds langer wachten, na succes meteen weer', () {
    final queue = PendingUploads()..add(at(0));
    expect(queue.readyAt(start), isTrue);
    queue.failed(start);
    expect(queue.readyAt(start.add(const Duration(seconds: 4))), isFalse);
    expect(queue.readyAt(start.add(const Duration(seconds: 5))), isTrue);
    queue.failed(start);
    expect(queue.readyAt(start.add(const Duration(seconds: 9))), isFalse);
    expect(PendingUploads.retryDelay(9), const Duration(seconds: 30));
    queue.sent();
    expect(queue.failures, 0);
    expect(queue.readyAt(start), isTrue);
  });

  test('een te lange rij wordt grover, het nieuwste punt blijft', () {
    final queue = PendingUploads(capacity: 10);
    for (var i = 0; i <= 10; i++) {
      queue.add(at(i * 5));
    }
    expect(queue.length, lessThanOrEqualTo(10));
    expect(queue.next!.updatedAt, start);
    var last = queue.next!;
    while (!queue.isEmpty) {
      last = queue.next!;
      queue.sent();
    }
    expect(last.updatedAt, start.add(const Duration(seconds: 50)));
  });
}
