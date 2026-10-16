import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:thuisradar/core/theme/app_theme.dart';
import 'package:thuisradar/features/auth/application/auth_providers.dart';
import 'package:thuisradar/features/family/application/family_providers.dart';
import 'package:thuisradar/features/parked_car/presentation/parked_car_picker_screen.dart';

void main() {
  testWidgets('Opslaan geeft het punt onder het kruis terug, Annuleren niets', (tester) async {
    LatLng? result = const LatLng(0, 0);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          currentUserIdProvider.overrideWithValue('papa'),
          myFamilyProvider.overrideWith((ref) async => null),
        ],
        child: MaterialApp(
          theme: AppTheme.light(),
          home: Builder(
            builder: (context) => TextButton(
              onPressed: () async => result = await Navigator.of(context).push<LatLng>(
                MaterialPageRoute(
                  builder: (_) => const ParkedCarPickerScreen(
                    initialCenter: LatLng(51.0543, 3.7174),
                    useGoogleMaps: false,
                  ),
                ),
              ),
              child: const Text('open'),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    expect(find.text('Sleep de kaart tot het kruis op je auto staat.'), findsOneWidget);
    await tester.tap(find.text('Auto hier opslaan'));
    await tester.pumpAndSettle();
    expect(result!.latitude, closeTo(51.0543, 1e-6));
    expect(result!.longitude, closeTo(3.7174, 1e-6));

    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Annuleren'));
    await tester.pumpAndSettle();
    expect(result, isNull);
  });
}
