import 'package:flutter_test/flutter_test.dart';
import 'package:thuisradar/features/location/domain/member_location.dart';
import 'package:thuisradar/features/location/domain/motion_activity.dart';
import 'package:thuisradar/features/location/domain/trip_mode_memory.dart';
import 'package:thuisradar/features/location/domain/trip_status.dart';

import 'fixtures/rit_16_oktober.dart';

/// De echte metingen van 16 oktober (met herkenning) door het geheugen: wat
/// de kaart per meting toont.
List<({String time, TripStatus status})> replay(String data) {
  final memory = TripModeMemory();
  return [
    for (final row in data.split(';'))
      () {
        final [time, speed, steps, activity] = row.split(',');
        final [h, m, s] = time.split(':').map(int.parse).toList();
        final location = MemberLocation(
          userId: 'franky',
          familyId: 'f',
          latitude: 51,
          longitude: 4,
          updatedAt: DateTime(2026, 10, 16, h, m, s),
          speedMps: double.tryParse(speed),
          steps: int.tryParse(steps),
          activity: MotionActivity.fromDb(activity),
        );
        final shown = memory.update([location]).single;
        return (time: time, status: TripStatus.at(shown, location.updatedAt));
      }(),
  ];
}

void main() {
  bool between(String time, String from, String to) => time.compareTo(from) >= 0 && time.compareTo(to) <= 0;

  group('fietsen (herkenning springt tussen fiets en voertuig)', () {
    final ride = replay(fietsVanMiddag);

    test('heen fietsen: nooit een auto, ook niet als het toestel "voertuig" zegt', () {
      for (final sample in ride.where((r) => between(r.time, '13:50:30', '13:53:56'))) {
        expect(
          sample.status.cycling,
          isTrue,
          reason: '${sample.time}: ${sample.status.state} ${sample.status.mode}',
        );
      }
    });

    test('terug fietsen: fiets', () {
      for (final sample in ride.where((r) => between(r.time, '14:14:52', '14:18:39'))) {
        expect(
          sample.status.cycling,
          isTrue,
          reason: '${sample.time}: ${sample.status.state} ${sample.status.mode}',
        );
      }
    });
  });

  group('auto (herkenning "voertuig", ook nog als hij al wandelt)', () {
    final ride = replay(autoVanMiddag);

    test('de rit, ook in de file: altijd een auto als hij beweegt', () {
      for (final sample in ride.where((r) => between(r.time, '15:47:55', '16:35:21'))) {
        if (sample.status.state != TripState.moving) continue;
        expect(sample.status.driving, isTrue, reason: '${sample.time}: ${sample.status.mode}');
      }
    });

    test('stilstaan in de file toont meteen stilstaand, weer rijden meteen rijden', () {
      for (final time in ['16:00:25', '16:02:05', '16:05:01', '16:14:01', '16:25:21']) {
        expect(ride.firstWhere((r) => r.time == time).status.state, TripState.stationary, reason: time);
      }
      for (final time in ['16:01:40', '16:04:35', '16:12:55', '16:14:58', '16:25:56']) {
        expect(ride.firstWhere((r) => r.time == time).status.driving, isTrue, reason: time);
      }
    });

    test('te voet naar en van de auto: wandelen', () {
      for (final sample in ride.where(
        (r) => between(r.time, '15:42:02', '15:47:11') || between(r.time, '16:39:18', '16:45:03'),
      )) {
        if (sample.status.state != TripState.moving) continue;
        expect(sample.status.walking, isTrue, reason: '${sample.time}: ${sample.status.mode}');
      }
    });
  });
}
