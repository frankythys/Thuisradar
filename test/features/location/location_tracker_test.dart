import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:thuisradar/features/location/application/location_providers.dart';
import 'package:thuisradar/features/location/application/tracking_status.dart';
import 'package:thuisradar/features/location/data/battery_source.dart';
import 'package:thuisradar/features/location/data/device_location_source.dart';
import 'package:thuisradar/features/location/data/location_repository.dart';
import 'package:thuisradar/features/location/domain/device_reading.dart';
import 'package:thuisradar/features/location/domain/member_location.dart';

class _MockDevice extends Mock implements DeviceLocationSource {}

class _MockBattery extends Mock implements BatterySource {}

class _MockRepository extends Mock implements LocationRepository {}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late _MockDevice device;
  late _MockBattery battery;
  late _MockRepository repository;
  late StreamController<DevicePosition> positions;
  late ProviderContainer container;

  setUpAll(() {
    registerFallbackValue(
      MemberLocation(userId: '', familyId: '', latitude: 0, longitude: 0, updatedAt: DateTime(2026)),
    );
  });

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    device = _MockDevice();
    battery = _MockBattery();
    repository = _MockRepository();
    positions = StreamController<DevicePosition>();

    when(() => device.positions()).thenAnswer((_) => positions.stream);
    when(() => battery.read()).thenAnswer((_) async => const BatteryReading(level: 64, isCharging: false));

    container = ProviderContainer(
      overrides: [
        deviceLocationSourceProvider.overrideWithValue(device),
        batterySourceProvider.overrideWithValue(battery),
        locationRepositoryProvider.overrideWithValue(repository),
      ],
    );
    addTearDown(container.dispose);
    // Niet awaiten: close() wacht op een luisteraar die er soms nooit is.
    addTearDown(() => unawaited(positions.close()));
  });

  final position = DevicePosition(latitude: 50.85, longitude: 4.35, timestamp: DateTime.now());

  Future<void> start() =>
      container.read(locationTrackerProvider.notifier).start(userId: 'u1', familyId: 'f1');

  test('zonder toestemming wordt er niets gevolgd', () async {
    when(() => device.ensureAccess()).thenAnswer((_) async => LocationAccess.denied);

    await start();

    expect(container.read(locationTrackerProvider), TrackingStatus.permissionDenied);
    verifyNever(() => device.positions());
  });

  test('nieuwe positie wordt met batterijstand geüpload', () async {
    when(() => device.ensureAccess()).thenAnswer((_) async => LocationAccess.granted);
    when(() => repository.upload(any())).thenAnswer((_) async {});

    await start();
    positions.add(position);
    await pumpEventQueue();

    final uploaded = verify(() => repository.upload(captureAny())).captured.single as MemberLocation;
    expect(uploaded.userId, 'u1');
    expect(uploaded.familyId, 'f1');
    expect(uploaded.latitude, 50.85);
    expect(uploaded.battery, 64);
    expect(container.read(locationTrackerProvider), TrackingStatus.active);
  });

  test('mislukte upload zet de status op offline en blijft volgen', () async {
    when(() => device.ensureAccess()).thenAnswer((_) async => LocationAccess.granted);
    when(() => repository.upload(any())).thenThrow(Exception('geen netwerk'));

    await start();
    positions.add(position);
    await pumpEventQueue();

    expect(container.read(locationTrackerProvider), TrackingStatus.offline);
    expect(positions.hasListener, isTrue);
  });
  test('gepauzeerd delen start geen locatievoorziening', () async {
    SharedPreferences.setMockInitialValues({'profile_u1_sharing': false});
    await start();
    expect(container.read(locationTrackerProvider), TrackingStatus.idle);
    verifyNever(() => device.ensureAccess());
    verifyNever(() => device.positions());
  });

  test('stop tijdens voorkeuren laden start geen GPS', () async {
    final pending = start();
    container.read(locationTrackerProvider.notifier).stop();
    await pending;
    verifyNever(() => device.ensureAccess());
    expect(container.read(locationTrackerProvider), TrackingStatus.idle);
  });

  test('stop tijdens toestemmingsvraag hangt geen stroom aan', () async {
    final access = Completer<LocationAccess>();
    when(() => device.ensureAccess()).thenAnswer((_) => access.future);
    final pending = start();
    await pumpEventQueue();
    container.read(locationTrackerProvider.notifier).stop();
    access.complete(LocationAccess.granted);
    await pending;
    verifyNever(() => device.positions());
    expect(container.read(locationTrackerProvider), TrackingStatus.idle);
  });

  test('stop tijdens batterij lezen uploadt geen locatie', () async {
    final reading = Completer<BatteryReading>();
    when(() => device.ensureAccess()).thenAnswer((_) async => LocationAccess.granted);
    when(() => battery.read()).thenAnswer((_) => reading.future);
    await start();
    positions.add(position);
    await pumpEventQueue();
    container.read(locationTrackerProvider.notifier).stop();
    reading.complete(const BatteryReading(level: 50, isCharging: false));
    await pumpEventQueue();
    verifyNever(() => repository.upload(any()));
  });
}
