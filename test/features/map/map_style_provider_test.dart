import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:thuisradar/features/map/application/map_style_provider.dart';
import 'package:thuisradar/features/map/domain/map_style.dart';
import 'package:thuisradar/features/map/presentation/widgets/map_style_button.dart';

void main() {
  test('automatisch: gewone kaart, op straatniveau satelliet', () {
    expect(showsSatellite(choice: null, zoom: 14), isFalse);
    expect(showsSatellite(choice: null, zoom: 18), isTrue);
  });

  test('een keuze met de knop wint, ook ingezoomd', () {
    expect(showsSatellite(choice: false, zoom: 19), isFalse);
    expect(showsSatellite(choice: true, zoom: 10), isTrue);
  });

  test('kaart start automatisch, ook na een keuze in de vorige sessie', () {
    final first = ProviderContainer();
    addTearDown(first.dispose);
    expect(first.read(mapSatelliteProvider), isNull);

    first.read(mapSatelliteProvider.notifier).choose(satellite: false);
    expect(first.read(mapSatelliteProvider), isFalse);

    // App opnieuw geopend.
    final second = ProviderContainer();
    addTearDown(second.dispose);
    expect(second.read(mapSatelliteProvider), isNull);
  });

  testWidgets('ingezoomd met automatische satelliet: de knop zet de gewone kaart', (tester) async {
    final controller = MapController();
    addTearDown(controller.dispose);
    bool? chosen;
    await tester.pumpWidget(
      MaterialApp(
        home: Stack(
          children: [
            FlutterMap(
              mapController: controller,
              options: const MapOptions(initialCenter: LatLng(51.2, 4.4), initialZoom: 14, maxZoom: 21),
              children: const [],
            ),
            Positioned(
              right: 16,
              bottom: 16,
              child: MapStyleButton(
                controller: controller,
                choice: null,
                onChoose: ({required satellite}) => chosen = satellite,
              ),
            ),
          ],
        ),
      ),
    );
    await tester.pump();
    controller.move(const LatLng(51.2, 4.4), 14);
    await tester.pump();
    expect(find.byTooltip('Satelliet'), findsOneWidget);

    controller.move(const LatLng(51.2, 4.4), 19);
    await tester.pump();
    expect(find.byTooltip('Gewone kaart'), findsOneWidget);

    await tester.tap(find.byTooltip('Gewone kaart'));
    expect(chosen, isFalse);
  });
}
