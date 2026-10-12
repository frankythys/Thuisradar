import 'package:flutter_test/flutter_test.dart';
import 'package:thuisradar/features/location/domain/driving_mode_memory.dart';
import 'package:thuisradar/features/location/domain/member_location.dart';
import 'package:thuisradar/features/location/domain/trip_status.dart';

void main() {
  final start = DateTime(2026, 10, 12, 12);
  late DrivingModeMemory memory;
  setUp(() => memory = DrivingModeMemory());
  MemberLocation fix(int seconds, double speed, {int? steps, String id = 'car'}) => MemberLocation(
    userId: id,
    familyId: 'f',
    latitude: 51,
    longitude: 3,
    updatedAt: start.add(Duration(seconds: seconds)),
    speedMps: speed,
    steps: steps,
  );
  TripStatus update(int seconds, double speed, {int? steps}) {
    final location = fix(seconds, speed, steps: steps);
    return TripStatus.at(memory.update([location], location.updatedAt).single, location.updatedAt);
  }

  test('afremmen en opnieuw optrekken na verkeerslicht blijft rijden', () {
    expect(update(0, 15).driving, isTrue);
    expect(update(5, 1.3).driving, isTrue);
    expect(update(10, 0).state, TripState.stationary);
    expect(update(25, 0).state, TripState.stationary);
    expect(update(30, 1.3).driving, isTrue);
    expect(update(35, 15).driving, isTrue);
  });
  test('na parkeren wordt wandeltempo opnieuw wandelen', () {
    update(0, 15);
    for (var second = 5; second <= 95; second += 15) {
      update(second, 0);
    }
    expect(update(100, 1.3).walking, isTrue);
  });
  test('stappen herkennen uitstappen ook na een korte stop', () {
    update(0, 15, steps: 100);
    update(5, 0, steps: 100);
    expect(update(10, 1.3, steps: 114).walking, isTrue);
  });
  test('onderbroken stroom houdt geen oude rijstatus vast', () {
    update(0, 15);
    expect(update(60, 1.3).walking, isTrue);
  });
  test('andere gebruiker en gewone wandeling nemen geen rijstatus over', () {
    update(0, 15);
    final walk = fix(5, 1.3, id: 'walk');
    final result = memory.update([fix(5, 1.3), walk], walk.updatedAt);
    expect(TripStatus.at(result.first, walk.updatedAt).driving, isTrue);
    expect(TripStatus.at(result.last, walk.updatedAt).walking, isTrue);
    expect(result.first.toJson(), isNot(contains('drivingHint')));
    expect(result.first.toJson(), isNot(contains('driving_hint')));
    expect(result.first.latitude, 51);
  });
}
