import 'package:flutter_test/flutter_test.dart';
import 'package:thuisradar/features/location/domain/diagnostic_tally.dart';
import 'package:thuisradar/features/location/domain/motion_filter.dart';

void main() {
  final now = DateTime(2026, 10, 10, 19, 31);

  test('samenvatting toont elke stap van de keten en zet de tellers op nul', () {
    final tally = DiagnosticTally()
      ..onReceived(now.subtract(const Duration(seconds: 4)))
      ..onReceived(now.subtract(const Duration(seconds: 2)))
      ..onAccepted()
      ..onRejected(RejectReason.inaccurate, 140)
      ..onRejected(RejectReason.inaccurate, 180)
      ..onUploadFailed();

    final line = tally.summary(now);

    expect(line, contains('ontvangen 2'));
    expect(line, contains('aanvaard 1'));
    expect(line, contains('geweigerd 2 [onnauwkeurig 2 (max 180 m)]'));
    expect(line, contains('upload ok 0'));
    expect(line, contains('upload mislukt 1'));
    expect(line, contains('laatste GPS 2 s geleden'));
    expect(line, contains('laatste upload nooit'));

    final next = tally.summary(now.add(const Duration(minutes: 1)));
    expect(next, startsWith('ontvangen 0 · aanvaard 0 · geweigerd 0 ·'));
    // Het laatste GPS-tijdstip blijft staan: zo zie je hoe lang de stroom stil is.
    expect(next, contains('laatste GPS 62 s geleden'));
  });

  test('tijdstempel in lokale tijd tot op de seconde', () {
    expect(diagnosticTimestamp(DateTime(2026, 10, 9, 7, 5, 3)), '2026-10-09 07:05:03');
  });
}
