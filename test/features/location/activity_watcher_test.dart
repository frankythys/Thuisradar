import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:thuisradar/features/location/application/activity_watcher.dart';
import 'package:thuisradar/features/location/data/activity_source.dart';
import 'package:thuisradar/features/location/domain/motion_activity.dart';

class _MockSource extends Mock implements ActivitySource {}

void main() {
  late _MockSource source;
  late StreamController<ActivityReading> readings;
  final now = DateTime(2026, 10, 15, 12);

  setUp(() {
    source = _MockSource();
    readings = StreamController<ActivityReading>.broadcast();
    addTearDown(readings.close);
    when(() => source.hasAccess()).thenAnswer((_) async => true);
    when(() => source.readings()).thenAnswer((_) => readings.stream);
  });

  test('met de flag aan: de laatste herkenning gaat mee', () async {
    final watcher = ActivityWatcher(source, enabled: true);
    await watcher.start();
    readings.add(ActivityReading(MotionActivity.vehicle, 90, now));
    await pumpEventQueue();
    expect(watcher.current(now), MotionActivity.vehicle);
    readings.add(ActivityReading(MotionActivity.bicycle, 80, now));
    await pumpEventQueue();
    expect(watcher.current(now), MotionActivity.bicycle);
  });

  test('met de flag uit wordt de sensor nooit aangesproken', () async {
    final watcher = ActivityWatcher(source, enabled: false);
    await watcher.start();
    verifyNever(() => source.hasAccess());
    verifyNever(() => source.readings());
    expect(watcher.current(now), isNull);
  });

  test('zonder toestemming geen herkenning', () async {
    when(() => source.hasAccess()).thenAnswer((_) async => false);
    final watcher = ActivityWatcher(source, enabled: true);
    await watcher.start();
    verifyNever(() => source.readings());
  });

  test('twee keer starten luistert maar één keer', () async {
    final watcher = ActivityWatcher(source, enabled: true);
    await watcher.start();
    await watcher.start();
    verify(() => source.readings()).called(1);
  });

  test('stop vergeet de herkenning en een trage start erna doet niets', () async {
    final access = Completer<bool>();
    when(() => source.hasAccess()).thenAnswer((_) => access.future);
    final watcher = ActivityWatcher(source, enabled: true);
    final starting = watcher.start();
    watcher.stop();
    access.complete(true);
    await starting;
    verifyNever(() => source.readings());
    expect(watcher.current(now), isNull);
  });

  test('een fout van de sensor (geen Play Services): verder zonder herkenning', () async {
    final watcher = ActivityWatcher(source, enabled: true);
    await watcher.start();
    readings.add(ActivityReading(MotionActivity.vehicle, 90, now));
    await pumpEventQueue();
    readings.addError(Exception('geen Play Services'));
    await pumpEventQueue();
    expect(watcher.current(now), isNull);
  });
}
