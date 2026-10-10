import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:thuisradar/features/geofencing/application/geofence_reporter.dart';
import 'package:thuisradar/features/geofencing/application/geofence_status.dart';
import 'package:thuisradar/features/geofencing/application/geofencing_providers.dart';
import 'package:thuisradar/features/geofencing/data/geofence_device_repository.dart';
import 'package:thuisradar/features/geofencing/data/native_geofence_source.dart';
import 'package:thuisradar/features/geofencing/domain/geofence_zone.dart';
import 'package:thuisradar/features/places/application/places_providers.dart';
import 'package:thuisradar/features/places/domain/place.dart';

import 'fake_geofence_store.dart';

class _MockReporter extends Mock implements GeofenceReporter {}

class _MockDevices extends Mock implements GeofenceDeviceRepository {}

/// Doet alsof Android de zones bijhoudt.
class _FakeNative implements NativeGeofenceSource {
  final registered = <String>[];
  final added = <String>[];
  final removed = <String>[];
  bool permission = true;

  @override
  Future<void> initialize() async {}

  @override
  Future<void> recreateAll() async {}

  @override
  Future<List<String>> registeredIds() async => List.of(registered);

  @override
  Future<void> add(GeofenceZone zone, GeofenceHandler callback) async {
    if (!permission) throw const GeofencePermissionMissing();
    registered.add(zone.id);
    added.add(zone.id);
  }

  @override
  Future<void> remove(String id) async {
    registered.remove(id);
    removed.add(id);
  }
}

Place _place(String id, {double lat = 51.0, int radius = 150}) => Place(
  id: id,
  familyId: 'f1',
  name: id,
  latitude: lat,
  longitude: 4.0,
  radiusMeters: radius,
  icon: 'home',
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late _FakeNative native;
  late FakeGeofenceStore store;
  late _MockDevices devices;
  late _MockReporter reporter;
  late StreamController<List<Place>> places;
  late ProviderContainer container;

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    native = _FakeNative();
    store = FakeGeofenceStore()..key = null;
    devices = _MockDevices();
    reporter = _MockReporter();
    places = StreamController<List<Place>>.broadcast();
    when(() => devices.register(any())).thenAnswer((_) async {});
    when(() => devices.unregister(any())).thenAnswer((_) async {});
    when(() => reporter.flush()).thenAnswer((_) async => const []);

    container = ProviderContainer(
      overrides: [
        nativeGeofenceSourceProvider.overrideWithValue(native),
        geofenceStoreProvider.overrideWithValue(store),
        geofenceDeviceRepositoryProvider.overrideWithValue(devices),
        geofenceReporterProvider.overrideWithValue(reporter),
        familyPlacesProvider('f1').overrideWith((ref) => places.stream),
      ],
    );
    addTearDown(container.dispose);
    // Niet awaiten: close() wacht op een luisteraar die er soms nooit is.
    addTearDown(() => unawaited(places.close()));
  });

  GeofenceStatus status() => container.read(geofenceSyncProvider);

  Future<void> start() => container.read(geofenceSyncProvider.notifier).start(userId: 'papa', familyId: 'f1');

  Future<void> emit(List<Place> list) async {
    places.add(list);
    await pumpEventQueue();
  }

  test('Papa start de app: toestel aangemeld en Thuis + Werk bewaakt', () async {
    await start();
    await emit([_place('thuis'), _place('werk', lat: 51.2)]);

    expect(status(), GeofenceStatus.active);
    verify(() => devices.register(store.key!)).called(1);
    verify(() => reporter.flush()).called(1);
    expect(native.registered.map(GeofenceZone.placeIdOf), ['thuis', 'werk']);
  });

  test('Thuis wordt aangepast: enkel Thuis opnieuw geregistreerd', () async {
    await start();
    await emit([_place('thuis'), _place('werk', lat: 51.2)]);
    native.added.clear();

    await emit([_place('thuis', radius: 250), _place('werk', lat: 51.2)]);

    expect(native.removed.single, startsWith('tr1|thuis|'));
    expect(native.added.single, 'tr1|thuis|51.00000|4.00000|250');
    expect(native.registered.length, 2);
  });

  test('plaats verwijderd en nieuwe toegevoegd', () async {
    await start();
    await emit([_place('thuis'), _place('werk', lat: 51.2)]);
    await emit([_place('thuis'), _place('school', lat: 51.1)]);

    expect(native.registered.map(GeofenceZone.placeIdOf), unorderedEquals(['thuis', 'school']));
  });

  test('locatie niet op "Altijd toestaan": status zegt het', () async {
    native.permission = false;
    await start();
    await emit([_place('thuis')]);

    expect(status(), GeofenceStatus.permissionMissing);
  });

  test('"Altijd toestaan" aangezet en terug naar de app: zones alsnog geregistreerd', () async {
    native.permission = false;
    await start();
    await emit([_place('thuis')]);
    expect(status(), GeofenceStatus.permissionMissing);

    // Papa zet in de instellingen "Altijd toestaan" aan en keert terug.
    native.permission = true;
    final retry = container.read(geofenceSyncProvider.notifier).retry();
    await pumpEventQueue();
    await emit([_place('thuis')]);
    await retry;

    expect(status(), GeofenceStatus.active);
    expect(native.registered.map(GeofenceZone.placeIdOf), ['thuis']);
  });

  test('alles in orde: terugkeren naar de app doet niets extra', () async {
    await start();
    await emit([_place('thuis')]);
    native.added.clear();

    await container.read(geofenceSyncProvider.notifier).retry();
    await pumpEventQueue();

    expect(native.added, isEmpty);
    verify(() => devices.register(any())).called(1);
  });

  test('migratie 014 nog niet gedraaid: geen zones, status notConfigured', () async {
    when(() => devices.register(any()))
        .thenThrow(const PostgrestException(message: 'not found', code: 'PGRST202'));
    await start();
    await emit([_place('thuis')]);

    expect(status(), GeofenceStatus.notConfigured);
    expect(native.registered, isEmpty);
  });

  test('delen staat uit: geen zones en sleutel weg', () async {
    SharedPreferences.setMockInitialValues({'profile_papa_sharing': false});
    native.registered.add('tr1|thuis|51.00000|4.00000|150');
    store.key = 'oude-sleutel';

    await start();
    await emit([_place('thuis')]);

    expect(status(), GeofenceStatus.idle);
    expect(native.registered, isEmpty);
    verify(() => devices.unregister('oude-sleutel')).called(1);
    expect(store.key, isNull);
  });

  test('afmelden: alle zones weg, sleutel afgemeld, latere plaatsen genegeerd', () async {
    await start();
    await emit([_place('thuis')]);
    final key = store.key!;

    await container.read(geofenceSyncProvider.notifier).stop();
    await emit([_place('thuis'), _place('werk', lat: 51.2)]);

    expect(native.registered, isEmpty);
    verify(() => devices.unregister(key)).called(1);
    expect(store.key, isNull);
    expect(status(), GeofenceStatus.idle);
  });
}
