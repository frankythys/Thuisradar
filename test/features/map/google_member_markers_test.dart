import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart' as gm;
import 'package:latlong2/latlong.dart';
import 'package:thuisradar/features/map/presentation/widgets/google_member_markers.dart';
import 'package:thuisradar/features/map/presentation/widgets/map_marker_spec.dart';
import 'package:thuisradar/features/map/presentation/widgets/widget_bitmap.dart';

void main() {
  testWidgets('Franky en Liam gaan naar Google, vast aan de kaart', (tester) async {
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
    final specs = [
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
      ),
    ];

    // Echte tijd: tekenen wacht tot de kaart even stil is.
    await tester.runAsync(() async {
      markers.update(specs, wrap: wrap, pixelRatio: 2, ready: Future<void>.value());
      await Future<void>.delayed(const Duration(milliseconds: 600));
    });

    expect(updates, hasLength(1));
    final first = updates.single;
    expect(first.map((m) => m.markerId.value), unorderedEquals(['member_Liam', 'member_Franky']));
    final liam = first.firstWhere((m) => m.markerId.value == 'member_Liam');
    // Pin boven het punt: anker onderaan het rondje (marge 24 rondom).
    expect(liam.anchor.dx, closeTo(0.5, 1e-9));
    expect(liam.anchor.dy, closeTo(64 / 88, 1e-9));
    expect(liam.position, const gm.LatLng(51.001, 3));

    // Zelfde inhoud opnieuw (bv. klok tikt): dezelfde markers, geen update naar Google.
    await tester.runAsync(() async {
      markers.update(specs, wrap: wrap, pixelRatio: 2, ready: Future<void>.value());
      await Future<void>.delayed(const Duration(milliseconds: 600));
    });
    expect(updates.last.firstWhere((m) => m.markerId.value == 'member_Liam'), same(liam));
  });

  testWidgets('rijden: het rondje schuift meteen mee, zonder opnieuw te tekenen', (tester) async {
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
    MapMarkerSpec franky(double lng) => MapMarkerSpec(
      id: 'member_Franky',
      point: LatLng(51.2, lng),
      width: 40,
      height: 40,
      child: const DecoratedBox(
        decoration: BoxDecoration(color: Colors.orange, shape: BoxShape.circle),
      ),
    );

    await tester.runAsync(() async {
      markers.update([franky(4.30)], wrap: wrap, pixelRatio: 2, ready: Future<void>.value());
      await Future<void>.delayed(const Duration(milliseconds: 600));
    });
    final drawn = updates.last.single;

    // Franky rijdt verder over de E17: elke nieuwe plaats komt meteen door
    // (binnen ~33 ms), met dezelfde afbeelding.
    final positions = <double>[];
    await tester.runAsync(() async {
      for (final lng in [4.301, 4.302, 4.303]) {
        markers.update([franky(lng)], wrap: wrap, pixelRatio: 2, ready: Future<void>.value());
        await Future<void>.delayed(const Duration(milliseconds: 50));
        positions.add(updates.last.single.position.longitude);
        expect(updates.last.single.icon, same(drawn.icon));
      }
    });
    expect(positions, [4.301, 4.302, 4.303]);
  });
}
