import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:thuisradar/features/map/domain/map_rotation.dart';
import 'package:thuisradar/features/map/presentation/widgets/map_compass_button.dart';
import 'package:thuisradar/features/map/presentation/widgets/map_gestures.dart';

void main() {
  late MapController controller;

  setUp(() => controller = MapController());
  tearDown(() => controller.dispose());

  Future<void> pumpMap(WidgetTester tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Stack(
          children: [
            TwistToRotate(
              builder: (context, rotate) => FlutterMap(
                mapController: controller,
                options: MapOptions(
                  initialCenter: const LatLng(51.2, 4.4),
                  initialZoom: 14,
                  interactionOptions: familyMapGestures(rotate: rotate),
                ),
                children: const [],
              ),
            ),
            Positioned(right: 16, bottom: 16, child: MapCompassButton(controller: controller)),
          ],
        ),
      ),
    );
    await tester.pump();
  }

  /// Twee vingers rond (400, 300), 300 px uit elkaar, die samen [degrees]
  /// graden draaien.
  Future<void> twist(WidgetTester tester, double degrees, {bool leftFirst = true}) async {
    const center = Offset(400, 300);
    const radius = 150.0;
    final first = await tester.createGesture(pointer: 1);
    final second = await tester.createGesture(pointer: 2);
    final side = leftFirst ? -1.0 : 1.0;
    await first.down(center + Offset(side * radius, 0));
    await second.down(center - Offset(side * radius, 0));
    await tester.pump();
    for (var step = 1; step <= 10; step++) {
      final angle = degrees * step / 10 * 3.141592653589793 / 180;
      final arm = Offset.fromDirection(angle, radius);
      await first.moveTo(center + arm * side);
      await second.moveTo(center - arm * side);
      await tester.pump(const Duration(milliseconds: 16));
    }
    await first.up();
    await second.up();
    // Ook de dubbeltik-timer van de kaart laten aflopen.
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pumpAndSettle();
  }

  for (final leftFirst in [true, false]) {
    final order = leftFirst ? 'linker' : 'rechter';

    testWidgets('$order vinger eerst: duidelijke draai draait de kaart mee', (tester) async {
      await pumpMap(tester);

      await twist(tester, 60, leftFirst: leftFirst);

      expect(isRotated(controller.camera.rotation), isTrue);
    });

    testWidgets('$order vinger eerst: kleine draai zet de kaart niet scheef', (tester) async {
      await pumpMap(tester);

      await twist(tester, 20, leftFirst: leftFirst);

      expect(controller.camera.rotation, 0);
    });
  }

  testWidgets('kompas verschijnt bij een gedraaide kaart en draait terug naar het noorden', (tester) async {
    await pumpMap(tester);
    final compass = find.byType(MapCompassButton);
    IgnorePointer ignore() => tester.widget<IgnorePointer>(
      find.descendant(of: compass, matching: find.byType(IgnorePointer)).first,
    );
    expect(ignore().ignoring, isTrue);

    controller.rotate(40);
    await tester.pumpAndSettle();
    expect(ignore().ignoring, isFalse);

    await tester.tap(find.byTooltip('Noorden boven'));
    await tester.pumpAndSettle();

    expect(controller.camera.rotation, closeTo(0, 1e-9));
    expect(ignore().ignoring, isTrue);
  });
}
