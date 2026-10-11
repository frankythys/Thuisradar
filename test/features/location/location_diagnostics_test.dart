import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:thuisradar/features/location/application/location_diagnostics.dart';
import 'package:thuisradar/features/location/application/location_providers.dart';
import 'package:thuisradar/features/location/data/battery_source.dart';
import 'package:thuisradar/features/location/data/device_location_source.dart';
import 'package:thuisradar/features/location/data/diagnostics_store.dart';
import 'package:thuisradar/features/location/data/location_repository.dart';
import 'package:thuisradar/features/location/domain/device_reading.dart';
import 'package:thuisradar/features/location/domain/member_location.dart';

class _MockDevice extends Mock implements DeviceLocationSource {}

class _MockBattery extends Mock implements BatterySource {}

class _MockRepository extends Mock implements LocationRepository {}

class _MemorySink implements DiagnosticsSink {
  final lines = <String>[];

  @override
  Future<void> append(List<String> lines) async => this.lines.addAll(lines);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() {
    registerFallbackValue(
      MemberLocation(userId: '', familyId: '', latitude: 0, longitude: 0, updatedAt: DateTime(2026)),
    );
  });

  group('locatietracker legt elke stap vast', () {
    late _MockDevice device;
    late _MockRepository repository;
    late StreamController<DevicePosition> positions;
    late _MemorySink sink;
    late LocationDiagnostics diagnostics;
    late ProviderContainer container;

    setUp(() {
      SharedPreferences.setMockInitialValues({});
      device = _MockDevice();
      final battery = _MockBattery();
      repository = _MockRepository();
      positions = StreamController<DevicePosition>();
      sink = _MemorySink();
      diagnostics = LocationDiagnostics(sink);

      when(() => device.ensureAccess()).thenAnswer((_) async => LocationAccess.granted);
      when(() => device.positions()).thenAnswer((_) => positions.stream);
      when(() => battery.read()).thenAnswer((_) async => const BatteryReading(level: 64, isCharging: false));

      container = ProviderContainer(
        overrides: [
          deviceLocationSourceProvider.overrideWithValue(device),
          batterySourceProvider.overrideWithValue(battery),
          locationRepositoryProvider.overrideWithValue(repository),
          locationDiagnosticsProvider.overrideWithValue(diagnostics),
        ],
      );
      addTearDown(container.dispose);
      addTearDown(() => unawaited(positions.close()));
    });

    Future<void> start() =>
        container.read(locationTrackerProvider.notifier).start(userId: 'u1', familyId: 'f1');

    DevicePosition fix({required double accuracy}) =>
        DevicePosition(latitude: 50.85, longitude: 4.35, timestamp: DateTime.now(), accuracyMeters: accuracy);

    test('ontvangen, geweigerd met reden en upload in het levensteken', () async {
      when(() => repository.upload(any())).thenAnswer((_) async {});
      await start();

      positions.add(fix(accuracy: 140));
      positions.add(fix(accuracy: 8));
      await pumpEventQueue();
      diagnostics.beat();
      await diagnostics.flush();

      expect(sink.lines.any((l) => l.endsWith('delen gestart')), isTrue);
      expect(sink.lines.any((l) => l.endsWith('stroom gestart')), isTrue);
      final beat = sink.lines.last;
      expect(
        beat,
        contains('levensteken: ontvangen 2 · aanvaard 1 · geweigerd 1 [onnauwkeurig 1 (max 140 m)]'),
      );
      expect(beat, contains('upload ok 1'));
    });

    test('mislukte upload wordt met de fout vastgelegd', () async {
      when(() => repository.upload(any())).thenThrow(Exception('geen netwerk'));
      await start();

      positions.add(fix(accuracy: 8));
      await pumpEventQueue();
      diagnostics.beat();
      await diagnostics.flush();

      expect(sink.lines.any((l) => l.contains('upload mislukt: Exception: geen netwerk')), isTrue);
      expect(sink.lines.last, contains('upload mislukt 1'));
    });

    test('einde en fout van de GPS-stroom worden vastgelegd', () async {
      await start();

      positions.addError(Exception('GPS uit'));
      await pumpEventQueue();
      await positions.close();
      await pumpEventQueue();
      await diagnostics.flush();

      expect(sink.lines.any((l) => l.contains('stroom fout: Exception: GPS uit')), isTrue);
      expect(sink.lines.any((l) => l.endsWith('stroom gestopt')), isTrue);
    });
  });

  test('appstart, levenscyclus en een te laat levensteken', () async {
    final sink = _MemorySink();
    var now = DateTime(2026, 10, 10, 19, 30);
    final diagnostics = LocationDiagnostics(sink, clock: () => now)..start();
    addTearDown(diagnostics.dispose);

    diagnostics.lifecycle(AppLifecycleState.paused);
    now = now.add(const Duration(hours: 14));
    diagnostics.beat();
    await diagnostics.flush();

    expect(sink.lines[0], '2026-10-10 19:30:00 appstart');
    expect(sink.lines[1], '2026-10-10 19:30:00 achtergrond');
    expect(sink.lines[2], contains('laatste GPS nooit'));
    expect(sink.lines[2], endsWith('vorig levensteken 50400 s geleden'));
  });
}
