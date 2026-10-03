import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:thuisradar/core/theme/app_theme.dart';
import 'package:thuisradar/features/location/data/device_location_source.dart';
import 'package:thuisradar/features/permissions/application/permission_service.dart';
import 'package:thuisradar/features/permissions/application/permissions_providers.dart';
import 'package:thuisradar/features/permissions/presentation/permissions_screen.dart';

class _FakePermissionService extends PermissionService {
  _FakePermissionService({required this.locationGranted}) : super(DeviceLocationSource());

  final bool locationGranted;
  bool locationRequested = false;

  @override
  Future<bool> requestLocation() async {
    locationRequested = true;
    return locationGranted;
  }

  @override
  Future<bool> requestNotifications() async => true;

  @override
  Future<bool> requestBatteryExemption() async => true;

  @override
  Future<void> openSettings() async {}
}

Future<void> _pump(WidgetTester tester, PermissionService service) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [permissionServiceProvider.overrideWithValue(service)],
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
  });

  testWidgets('Toestaan vraagt locatie en sluit daarna af', (tester) async {
    final service = _FakePermissionService(locationGranted: true);
    await _pump(tester, service);

    await tester.ensureVisible(find.text('Toestaan'));
    await tester.tap(find.text('Toestaan'));
    await tester.pumpAndSettle();

    expect(service.locationRequested, isTrue);
    expect(find.text('Toestemmingen voor gemoedsrust'), findsNothing);
  });

  testWidgets('geweigerde locatie toont uitleg en blokkeert niet', (tester) async {
    final service = _FakePermissionService(locationGranted: false);
    await _pump(tester, service);

    await tester.ensureVisible(find.text('Toestaan'));
    await tester.tap(find.text('Toestaan'));
    await tester.pump(); // async-verzoeken afronden
    await tester.pump(const Duration(milliseconds: 300)); // snackbar animeert in
    expect(find.textContaining('later aanzetten via Instellingen'), findsOneWidget);
  });
}
