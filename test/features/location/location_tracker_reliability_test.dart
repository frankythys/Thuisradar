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

      when(() => device.positions()).thenAnswer((_) => stream.stream);
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

      when(() => device.positions()).thenAnswer((_) {
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

  test('een rit herstart de GPS-stroom nooit (voorgronddienst blijft draaien)', () {
    fakeAsync((async) {
      final device = _MockDevice();
      final battery = _MockBattery();
      final repository = _MockRepository();
      final stream = StreamController<DevicePosition>();
      addTearDown(() => unawaited(stream.close()));
      var opened = 0;
      when(() => device.positions()).thenAnswer((_) {
        opened++;
        return stream.stream;
      });
      when(() => repository.upload(any())).thenAnswer((_) async {});

      final container = containerWith(device, battery, repository);
      addTearDown(container.dispose);
      container.read(locationTrackerProvider.notifier).start(userId: 'u1', familyId: 'f1');
      async.flushMicrotasks();

      // Thuis stil, dan vertrekken met de auto (±15 m/s), dan weer stoppen.
      final base = DateTime.now().subtract(const Duration(seconds: 80));
      for (var i = 0; i < 14; i++) {
        final driving = i >= 3 && i < 10;
        stream.add(
          DevicePosition(
            latitude: 51.2 + (driving ? (i - 2) * 0.0007 : (i < 3 ? 0 : 0.0049)),
            longitude: 4.4,
            timestamp: base.add(Duration(seconds: i * 5)),
            accuracyMeters: 5,
            speedMps: driving ? 15 : 0,
          ),
        );
        async.flushMicrotasks();
      }
      container.read(locationTrackerProvider.notifier).setFastUpdates(true);
      async.flushMicrotasks();

      expect(opened, 1);
      verify(() => repository.upload(any())).called(greaterThan(2));
    });
  });

  test('terug in de app: een stilgevallen GPS-stroom wordt opnieuw aangehaakt', () {
    fakeAsync((async) {
      final device = _MockDevice();
      final battery = _MockBattery();
      final repository = _MockRepository();
      final streams = <StreamController<DevicePosition>>[];
      when(() => device.positions()).thenAnswer((_) {
        final c = StreamController<DevicePosition>();
        streams.add(c);
        return c.stream;
      });
      when(() => device.currentPosition()).thenAnswer(
        (_) async =>
            DevicePosition(latitude: 51.2, longitude: 4.4, timestamp: DateTime.now(), accuracyMeters: 8),
      );
      when(() => repository.upload(any())).thenAnswer((_) async {});

      final container = containerWith(device, battery, repository);
      addTearDown(container.dispose);
      container.read(locationTrackerProvider.notifier).start(userId: 'u1', familyId: 'f1');
      async.flushMicrotasks();
      expect(streams, hasLength(1));

      // Geen enkele meting (Android stopte de dienst op de achtergrond).
      container.read(locationTrackerProvider.notifier).resume();
      async.flushMicrotasks();

      expect(streams, hasLength(2));
      final uploaded = verify(() => repository.upload(captureAny())).captured.single as MemberLocation;
      expect(uploaded.latitude, 51.2);
      expect(container.read(locationTrackerProvider), TrackingStatus.active);
    });
  });

  test('Verversen uploadt meteen een verse positie, ook binnen het upload-interval', () {
    fakeAsync((async) {
      final device = _MockDevice();
      final battery = _MockBattery();
      final repository = _MockRepository();
      final stream = StreamController<DevicePosition>();
      addTearDown(() => unawaited(stream.close()));
      when(() => device.positions()).thenAnswer((_) => stream.stream);
      when(() => repository.upload(any())).thenAnswer((_) async {});

      final container = containerWith(device, battery, repository);
      addTearDown(container.dispose);
      container.read(locationTrackerProvider.notifier).start(userId: 'u1', familyId: 'f1');
      async.flushMicrotasks();

      final now = DateTime.now();
      stream.add(posAt(now.subtract(const Duration(seconds: 3))));
      async.flushMicrotasks();
      when(() => device.currentPosition()).thenAnswer((_) async => posAt(now, lat: 50.8505));
      unawaited(container.read(locationTrackerProvider.notifier).refreshNow());
      async.flushMicrotasks();

      final uploads = verify(() => repository.upload(captureAny())).captured.cast<MemberLocation>();
      expect(uploads.map((l) => l.latitude), [50.85, 50.8505]);
    });
  });

  test('zonder toestemming doet terugkeren naar de app niets', () {
    fakeAsync((async) {
      final device = _MockDevice();
      final battery = _MockBattery();
      final repository = _MockRepository();
      final container = containerWith(device, battery, repository);
      addTearDown(container.dispose);
      when(() => device.ensureAccess()).thenAnswer((_) async => LocationAccess.denied);
      container.read(locationTrackerProvider.notifier).start(userId: 'u1', familyId: 'f1');
      async.flushMicrotasks();

      container.read(locationTrackerProvider.notifier).resume();
      async.flushMicrotasks();
      verifyNever(() => device.positions());
      verifyNever(() => device.currentPosition());
    });
  });
}
