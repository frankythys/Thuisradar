import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart' as gm;
import 'package:latlong2/latlong.dart';
import 'package:thuisradar/features/map/presentation/widgets/google_member_markers.dart';
import 'package:thuisradar/features/map/presentation/widgets/map_marker_spec.dart';
import 'package:thuisradar/features/map/presentation/widgets/widget_bitmap.dart';

void main() {
  testWidgets('Franky (geselecteerd) en Liam gaan naar Google; lichtkring op Franky', (tester) async {
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

    final updates = <({Set<gm.Marker> markers, GooglePulse? pulse})>[];
    final markers = GoogleMemberMarkers(onChanged: (m, p) => updates.add((markers: m, pulse: p)));
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
        pulse: const PulseSpot(center: Offset(20, 19), radius: 19),
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
    expect(first.markers.map((m) => m.markerId.value), unorderedEquals(['member_Liam', 'member_Franky']));
    final liam = first.markers.firstWhere((m) => m.markerId.value == 'member_Liam');
    // Pin boven het punt: anker onderaan het rondje (marge 24 rondom).
    expect(liam.anchor.dx, closeTo(0.5, 1e-9));
    expect(liam.anchor.dy, closeTo(64 / 88, 1e-9));
    expect(liam.position, const gm.LatLng(51.001, 3));

    // Lichtkring: midden van Franky's rondje, 21 punten boven zijn kaartpunt.
    final pulse = first.pulse!;
    expect(pulse.point, const LatLng(51, 3));
    expect(pulse.dx, 0);
    expect(pulse.dy, -21);
    expect(pulse.radius, 19);

    // Zelfde inhoud opnieuw (bv. klok tikt): dezelfde markers, geen update naar Google.
    await tester.runAsync(() async {
      markers.update(specs, wrap: wrap, pixelRatio: 2, ready: Future<void>.value());
      await Future<void>.delayed(const Duration(milliseconds: 600));
    });
    expect(updates.last.markers.firstWhere((m) => m.markerId.value == 'member_Liam'), same(liam));
  });
}
