import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart' as gm;
import 'package:latlong2/latlong.dart';
import 'package:thuisradar/features/map/presentation/widgets/google_member_markers.dart';
import 'package:thuisradar/features/map/presentation/widgets/map_marker_spec.dart';
import 'package:thuisradar/features/map/presentation/widgets/widget_bitmap.dart';

void main() {
  testWidgets('Franky (geselecteerd) pulseert in Google, Liam blijft ongewijzigd', (tester) async {
    late Widget Function(Widget) wrap;
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) {
            wrap = wrapForBitmap(context);
            return const SizedBox();
          },
        ),
      ),
    );

    final updates = <Set<gm.Marker>>[];
    final markers = GoogleMemberMarkers(onChanged: updates.add);
    addTearDown(markers.dispose);

    Widget dot(Color color) => DecoratedBox(
      decoration: BoxDecoration(color: color, shape: BoxShape.circle),
    );
    // Echte tijd: tekenen wacht op stilte en de puls wisselt op een timer.
    await tester.runAsync(() async {
      markers.update(
        [
          MapMarkerSpec(
            id: 'member_Liam',
            point: const LatLng(51.001, 3),
            width: 40,
            height: 40,
            alignment: Alignment.topCenter,
            child: dot(Colors.green),
          ),
          MapMarkerSpec(
            id: 'member_Franky',
            point: const LatLng(51, 3),
            width: 40,
            height: 40,
            alignment: Alignment.topCenter,
            child: dot(Colors.orange),
            animated: (phase) => dot(Color.lerp(Colors.orange, Colors.purple, phase)!),
          ),
        ],
        wrap: wrap,
        pixelRatio: 2,
        ready: Future<void>.value(),
      );
      await Future<void>.delayed(const Duration(milliseconds: 1200));
    });

    expect(updates, isNotEmpty);
    final first = updates.first;
    expect(first.map((m) => m.markerId.value), unorderedEquals(['member_Liam', 'member_Franky']));
    final liam = first.firstWhere((m) => m.markerId.value == 'member_Liam');
    // Pin boven het punt: anker onderaan het rondje (marge 24 rondom).
    expect(liam.anchor.dx, closeTo(0.5, 1e-9));
    expect(liam.anchor.dy, closeTo(64 / 88, 1e-9));
    expect(liam.position, const gm.LatLng(51.001, 3));

    // De lichtkring wisselt van beeld; Liam blijft exact dezelfde marker.
    expect(updates.length, greaterThan(2));
    final last = updates.last;
    expect(last.firstWhere((m) => m.markerId.value == 'member_Liam'), same(liam));
    final frankyIcons = {
      for (final update in updates) update.firstWhere((m) => m.markerId.value == 'member_Franky').icon,
    };
    expect(frankyIcons.length, greaterThan(1));
  });
}
