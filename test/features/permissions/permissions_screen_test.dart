import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:thuisradar/core/theme/app_theme.dart';
import 'package:thuisradar/features/location/application/location_providers.dart';
import 'package:thuisradar/features/location/application/location_tracker.dart';
import 'package:thuisradar/features/location/application/tracking_status.dart';
import 'package:thuisradar/features/location/data/device_location_source.dart';
import 'package:thuisradar/features/location/data/step_source.dart';
import 'package:thuisradar/features/permissions/application/permission_service.dart';
import 'package:thuisradar/features/permissions/application/permissions_providers.dart';
import 'package:thuisradar/features/permissions/presentation/permissions_screen.dart';

class _FakePermissionService extends PermissionService {
  _FakePermissionService({required this.locationGranted}) : super(DeviceLocationSource(), StepSource());

  final bool locationGranted;
  bool locationRequested = false;
  bool batteryRequested = false;
  bool stepsRequested = false;

  @override
  Future<bool> requestLocation() async {
    locationRequested = true;
    return locationGranted;
  }

  @override
  Future<bool> requestNotifications() async => true;

  @override
  Future<bool> requestBatteryExemption() async {
    batteryRequested = true;
    return true;
  }

  @override
  Future<bool> requestSteps() async {
    stepsRequested = true;
    return true;
  }

  @override
  Future<void> openSettings() async {}
}

var _trackerRetries = 0;

class _Tracker extends LocationTracker {
  @override
  TrackingStatus build() => TrackingStatus.permissionDenied;

  @override
  Future<void> retryStart() async => _trackerRetries++;
}

Future<void> _pump(WidgetTester tester, PermissionService service) async {
  _trackerRetries = 0;
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        permissionServiceProvider.overrideWithValue(service),
        locationTrackerProvider.overrideWith(_Tracker.new),
      ],
      child: MaterialApp(
        theme: AppTheme.light(),
        home: Scaffold(
          body: Builder(
            builder: (context) => Center(
              child: ElevatedButton(
                onPressed: () =>
                    Navigator.of(context)
                        .push(MaterialPageRoute<void>(builder: (_) => const PermissionsScreen())),
                child: const Text('open'),
              ),
            ),
          ),
        ),
      ),
    ),
  );
  await tester.tap(find.text('open'));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('Later instellen sluit het scherm zonder iets te vragen', (tester) async {
    final service = _FakePermissionService(locationGranted: true);
    await _pump(tester, service);

    expect(find.text('Toestemmingen voor gemoedsrust'), findsOneWidget);
    await tester.ensureVisible(find.text('Later instellen'));
    await tester.tap(find.text('Later instellen'));
    await tester.pumpAndSettle();

    expect(find.text('Toestemmingen voor gemoedsrust'), findsNothing);
    expect(service.locationRequested, isFalse);
    expect(service.stepsRequested, isFalse);
  });

  testWidgets('Toestaan: eerst de uitleg, na Akkoord pas de vraag om locatie', (tester) async {
    final service = _FakePermissionService(locationGranted: true);
    await _pump(tester, service);

    await tester.ensureVisible(find.text('Toestaan'));
    await tester.tap(find.text('Toestaan'));
    // Geen pumpAndSettle: de laadcirkel op de knop draait zolang de uitleg open staat.
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    // De uitleg (Play: prominente melding) staat er vóór de Android-vraag.
    expect(find.text('Locatie, ook op de achtergrond'), findsOneWidget);
    expect(find.textContaining('ook als de app gesloten is of niet gebruikt wordt'), findsOneWidget);
    expect(service.locationRequested, isFalse);

    await tester.tap(find.text('Akkoord'));
    await tester.pumpAndSettle();

    expect(service.locationRequested, isTrue);
    expect(_trackerRetries, 1);
    expect(service.stepsRequested, isTrue);
    // Batterij-uitzondering staat standaard uit.
    expect(service.batteryRequested, isFalse);
    expect(find.text('Toestemmingen voor gemoedsrust'), findsNothing);
  });

  testWidgets('Nee, bedankt: geen vraag om locatie, wel de uitleg hoe je het later aanzet', (tester) async {
    final service = _FakePermissionService(locationGranted: true);
    await _pump(tester, service);

    await tester.ensureVisible(find.text('Toestaan'));
    await tester.tap(find.text('Toestaan'));
    // Geen pumpAndSettle: de laadcirkel op de knop draait zolang de uitleg open staat.
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    await tester.tap(find.text('Nee, bedankt'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(service.locationRequested, isFalse);
    expect(_trackerRetries, 0);
    expect(find.textContaining('later aanzetten via Instellingen'), findsOneWidget);
  });

  testWidgets('geweigerde locatie toont uitleg en blokkeert niet', (tester) async {
    final service = _FakePermissionService(locationGranted: false);
    await _pump(tester, service);

    await tester.ensureVisible(find.text('Toestaan'));
    await tester.tap(find.text('Toestaan'));
    // Geen pumpAndSettle: de laadcirkel op de knop draait zolang de uitleg open staat.
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    await tester.tap(find.text('Akkoord'));
    await tester.pump(); // async-verzoeken afronden
    await tester.pump(const Duration(milliseconds: 300)); // snackbar animeert in
    expect(find.textContaining('later aanzetten via Instellingen'), findsOneWidget);
  });
}
