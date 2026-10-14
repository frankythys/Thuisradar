import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:thuisradar/features/map/presentation/widgets/google_walker_overlay.dart';
import 'package:thuisradar/features/map/presentation/widgets/member_history_bubble.dart';

void main() {
  Future<MapController> pumpOverlay(WidgetTester tester) async {
    final controller = MapController();
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: FlutterMap(
            mapController: controller,
            options: const MapOptions(initialCenter: LatLng(51, 3), initialZoom: 17),
            children: const [
              MarkerLayer(
                markers: [
                  Marker(
                    point: LatLng(51, 3),
                    width: 54,
                    height: 34,
                    child: GoogleWalkerOverlay(width: 52, height: 32),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
    await tester.pump();
    return controller;
  }

  double opacity(WidgetTester tester) => tester
      .widget<AnimatedOpacity>(
        find.descendant(of: find.byType(GoogleWalkerOverlay), matching: find.byType(AnimatedOpacity)),
      )
      .opacity;

  testWidgets('zichtbaar zolang de kaart stilstaat, met een vlak in de kleur van de ballon', (tester) async {
    await pumpOverlay(tester);
    expect(opacity(tester), 1);
    final patch = tester.widget<ColoredBox>(
      find.descendant(of: find.byType(GoogleWalkerOverlay), matching: find.byType(ColoredBox)),
    );
    expect(patch.color, kBubbleColor);
    // Tikken gaat erdoor naar de ballon.
    expect(
      find.descendant(of: find.byType(GoogleWalkerOverlay), matching: find.byType(IgnorePointer)),
      findsWidgets,
    );
  });

  testWidgets('verdwijnt meteen als de kaart beweegt en komt terug na stilstand', (tester) async {
    final controller = await pumpOverlay(tester);

    controller.move(const LatLng(51.0001, 3), 17);
    await tester.pump();
    expect(opacity(tester), 0, reason: 'Google volgt de kaart met vertraging');

    // Blijft weg zolang er beweging is.
    await tester.pump(GoogleWalkerOverlay.settle ~/ 2);
    controller.move(const LatLng(51.0002, 3), 17);
    await tester.pump();
    await tester.pump(GoogleWalkerOverlay.settle ~/ 2);
    expect(opacity(tester), 0);

    // Na stilstand terug.
    await tester.pump(GoogleWalkerOverlay.settle);
    expect(opacity(tester), 1);
  });

  testWidgets('draaien en zoomen tellen ook als beweging', (tester) async {
    final controller = await pumpOverlay(tester);

    controller.rotate(30);
    await tester.pump();
    expect(opacity(tester), 0);
    await tester.pump(GoogleWalkerOverlay.settle + const Duration(milliseconds: 50));
    expect(opacity(tester), 1);

    controller.move(const LatLng(51, 3), 16);
    await tester.pump();
    expect(opacity(tester), 0);
  });
}
