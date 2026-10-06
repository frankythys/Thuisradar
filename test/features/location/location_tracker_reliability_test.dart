import 'dart:async';

import 'package:fake_async/fake_async.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:thuisradar/features/location/application/location_providers.dart';
import 'package:thuisradar/features/location/application/tracking_status.dart';
import 'package:thuisradar/features/location/data/battery_source.dart';
import 'package:thuisradar/features/location/data/device_location_source.dart';
import 'package:thuisradar/features/location/data/location_repository.dart';
import 'package:thuisradar/features/location/domain/device_reading.dart';
import 'package:thuisradar/features/location/domain/member_location.dart';
import 'package:thuisradar/features/profile/application/profile_providers.dart';
import 'package:thuisradar/features/profile/data/profile_preferences.dart';

class _MockDevice extends Mock implements DeviceLocationSource {}

class _MockBattery extends Mock implements BatterySource {}

class _MockRepository extends Mock implements LocationRepository {}

class _MockPrefs extends Mock implements ProfilePreferences {}

void main() {
  setUpAll(() {
    registerFallbackValue(Duration.zero);
    registerFallbackValue(
      MemberLocation(userId: '', familyId: '', latitude: 0, longitude: 0, updatedAt: DateTime(2026)),
    );
  });

  DevicePosition posAt(DateTime at, {double lat = 50.85}) =>
      DevicePosition(latitude: lat, longitude: 4.35, timestamp: at);

  ProviderContainer containerWith(_MockDevice device, _MockBattery battery, _MockRepository repository) {
    final prefs = _MockPrefs();
    when(() => prefs.sharing(any())).thenAnswer((_) async => true);
    when(() => device.ensureAccess()).thenAnswer((_) async => LocationAccess.granted);
    when(() => battery.read()).thenAnswer((_) async => const BatteryReading(level: 50, isCharging: false));
    return ProviderContainer(
      overrides: [
        deviceLocationSourceProvider.overrideWithValue(device),
        batterySourceProvider.overrideWithValue(battery),
        locationRepositoryProvider.overrideWithValue(repository),
        profilePreferencesProvider.overrideWithValue(prefs),
      ],
    );
  }

  test('een hangende upload blokkeert de volgende metingen niet', () {
    fakeAsync((async) {
      final device = _MockDevice();
      final battery = _MockBattery();
      final repository = _MockRepository();
      final stream = StreamController<DevicePosition>();
      addTearDown(() => unawaited(stream.close()));

      when(() => device.positions(interval: any(named: 'interval'))).thenAnswer((_) => stream.stream);
      final hang = Completer<void>();
      var uploads = 0;
      when(() => repository.upload(any())).thenAnswer((_) {
        uploads++;
        return uploads == 1 ? hang.future : Future<void>.value();
      });

      final container = containerWith(device, battery, repository);
      addTearDown(container.dispose);

      container.read(locationTrackerProvider.notifier).start(userId: 'u1', familyId: 'f1');
      async.flushMicrotasks();

      final base = DateTime.now();
      stream.add(posAt(base.subtract(const Duration(seconds: 40))));
      async.flushMicrotasks();

      // De eerste upload blijft hangen; na de timeout gaat de status offline en
      // komt de keten weer vrij in plaats van voor altijd te blokkeren.
      async.elapse(const Duration(seconds: 16));
      expect(container.read(locationTrackerProvider), TrackingStatus.offline);

      stream.add(posAt(base.subtract(const Duration(seconds: 10)), lat: 50.8505));
      async.elapse(const Duration(seconds: 1));
      expect(uploads, 2);
      expect(container.read(locationTrackerProvider), TrackingStatus.active);
    });
  });

  test('een onderbroken locatiestroom herstelt zichzelf zonder herstart', () {
    fakeAsync((async) {
      final device = _MockDevice();
      final battery = _MockBattery();
      final repository = _MockRepository();
      final streams = <StreamController<DevicePosition>>[];

      when(() => device.positions(interval: any(named: 'interval'))).thenAnswer((_) {
        final c = StreamController<DevicePosition>();
        streams.add(c);
        return c.stream;
      });
      when(() => repository.upload(any())).thenAnswer((_) async {});

      final container = containerWith(device, battery, repository);
      addTearDown(container.dispose);

      container.read(locationTrackerProvider.notifier).start(userId: 'u1', familyId: 'f1');
      async.flushMicrotasks();
      expect(streams, hasLength(1));

      // De stroom valt weg (Android beëindigt hem onderweg); na de backoff
      // moet de tracker zichzelf opnieuw abonneren.
      unawaited(streams.first.close());
      async.elapse(const Duration(seconds: 6));
      expect(streams, hasLength(2));
    });
  });
}
