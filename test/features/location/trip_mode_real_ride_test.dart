import 'package:flutter_test/flutter_test.dart';
import 'package:thuisradar/features/location/domain/member_location.dart';
import 'package:thuisradar/features/location/domain/trip_mode_memory.dart';
import 'package:thuisradar/features/location/domain/trip_status.dart';

import 'fixtures/rit_14_oktober.dart';

/// De echte rit van 14 oktober door het geheugen: wat de kaart per meting toont.
List<({String time, TripStatus status, double? speed})> replay(String data) {
  final memory = TripModeMemory();
  return [
    for (final row in data.split(';'))
      () {
        final [time, speed, steps] = row.split(',');
        final [h, m, s] = time.split(':').map(int.parse).toList();
        final location = MemberLocation(
          userId: 'franky',
          familyId: 'f',
          latitude: 51,
          longitude: 4,
          updatedAt: DateTime(2026, 10, 14, h, m, s),
          speedMps: double.tryParse(speed),
          steps: int.tryParse(steps),
        );
        final shown = memory.update([location]).single;
        return (time: time, status: TripStatus.at(shown, location.updatedAt), speed: location.speedMps);
      }(),
  ];
}

void main() {
  final ride = replay(ritVanMiddag);
  bool between(String time, String from, String to) => time.compareTo(from) >= 0 && time.compareTo(to) <= 0;

  test('in de auto (ook in de file en na een stop van 2 min): altijd rijden, nooit wandelen of fietsen', () {
    for (final sample in ride.where((r) => between(r.time, '15:42:25', '16:42:07'))) {
      if (sample.status.state != TripState.moving) continue;
      expect(sample.status.driving, isTrue, reason: '${sample.time}: ${sample.status.mode}');
    }
  });

  test('te voet naar en van de auto: wandelen', () {
    for (final sample in ride.where(
      (r) => between(r.time, '15:35:34', '15:41:40') || between(r.time, '16:59:12', '17:09:40'),
    )) {
      if (sample.status.state != TripState.moving) continue;
      expect(
        sample.status.walking,
        isTrue,
        reason: '${sample.time}: ${sample.status.state} ${sample.status.mode}',
      );
    }
  });

  test('een bevestigde stilstand toont meteen stilstaand', () {
    for (final sample in ride.where((r) => r.speed == 0)) {
      expect(sample.status.state, TripState.stationary, reason: sample.time);
    }
  });

  test('vertrek: de eerste bewegende meting is meteen onderweg', () {
    expect(ride.firstWhere((r) => r.time == '15:35:34').status.walking, isTrue);
    expect(ride.firstWhere((r) => r.time == '15:42:25').status.driving, isTrue);
    expect(ride.firstWhere((r) => r.time == '15:46:10').status.driving, isTrue);
    expect(ride.firstWhere((r) => r.time == '16:11:03').status.driving, isTrue);
  });
}
