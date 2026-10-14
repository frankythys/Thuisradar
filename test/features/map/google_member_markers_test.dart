import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart' as gm;
import 'package:latlong2/latlong.dart';
import 'package:thuisradar/features/map/domain/native_marker_frame.dart';
import 'package:thuisradar/features/map/presentation/widgets/google_member_markers.dart';
import 'package:thuisradar/features/map/presentation/widgets/map_marker_spec.dart';
import 'package:thuisradar/features/map/presentation/widgets/widget_bitmap.dart';

void main() {
  testWidgets('rijden hergebruikt de afbeelding en vernieuwt gewijzigde inhoud', (tester) async {
    late Widget Function(Widget) wrap;
    var drawings = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) {
            final original = wrapForBitmap(context);
            wrap = (child) {
              drawings++;
              return original(child);
            };
            return const SizedBox();
          },
        ),
      ),
    );
    final updates = <Set<gm.Marker>>[];
    late Completer<void> arrived;
    final markers = GoogleMemberMarkers(
      onChanged: (value) {
        updates.add(value);
        if (!arrived.isCompleted &&
            value.any((marker) => (marker.position.longitude - 3.00045).abs() < .000001)) {
          arrived.complete();
        }
      },
    );
    addTearDown(markers.dispose);
    MapMarkerSpec spec(Color color, double lng) => MapMarkerSpec(
      id: 'car',
      point: LatLng(51, lng),
      width: 40,
      height: 40,
      imageKey: color,
      child: ColoredBox(color: color),
    );
    await tester.runAsync(() async {
      arrived = Completer<void>();
      markers.update([spec(Colors.orange, 3)], wrap: wrap, pixelRatio: 1, ready: Future<void>.value());
      await Future<void>.delayed(const Duration(milliseconds: 300));
      final icon = updates.last.single.icon;
      for (var i = 1; i <= 20; i++) {
        markers.update(
          [spec(Colors.orange, 3 + i * .00001)],
          wrap: wrap,
          pixelRatio: 1,
          ready: Future<void>.value(),
        );
        await Future<void>.delayed(const Duration(milliseconds: 30));
      }
      expect(drawings, 1);
      expect(updates.last.single.icon, same(icon));
      for (var i = 21; i <= 45; i++) {
        markers.update(
          [spec(Colors.green, 3 + i * .00001)],
          wrap: wrap,
          pixelRatio: 1,
          ready: Future<void>.value(),
        );
        await Future<void>.delayed(const Duration(milliseconds: 30));
      }
      // De plaatsupdates zijn begrensd tot 33 ms; de invoer komt elke 30 ms.
      // Wacht op het laatste beeld, ook als de laatste invoer nog in de wachtrij staat.
      await arrived.future.timeout(const Duration(seconds: 2));
      expect(drawings, 2);
      expect(updates.last.single.icon, isNot(same(icon)));
      expect(updates.last.single.position.longitude, closeTo(3.00045, .000001));
    });
  });
  testWidgets('nieuwe Google-marker verschijnt tijdens doorlopende plaatsupdates', (tester) async {
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
    await tester.runAsync(() async {
      for (var i = 0; i < 25; i++) {
        markers.update(
          [
            MapMarkerSpec(
              id: 'car',
              point: LatLng(51, 3 + i * .00001),
              width: 40,
              height: 40,
              child: const ColoredBox(color: Colors.orange),
            ),
          ],
          wrap: wrap,
          pixelRatio: 1,
          ready: Future<void>.value(),
        );
        await Future<void>.delayed(const Duration(milliseconds: 30));
      }
      expect(
        updates.where((value) => value.isNotEmpty),
        isNotEmpty,
        reason: 'Tekenen mag niet blijven wachten tot een rijdende auto stilstaat.',
      );
    });
  });
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

  testWidgets('wandel-GIF: de beelden wisselen op het tempo van de GIF, zonder opnieuw te tekenen', (
    tester,
  ) async {
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
    Widget box(Color color) => ColoredBox(color: color);
    final frames = [
      for (final color in [Colors.red, Colors.green, Colors.blue])
        (child: box(color), duration: const Duration(milliseconds: 60)),
    ];
    MapMarkerSpec walker(double lng) => MapMarkerSpec(
      id: 'walker_Franky',
      point: LatLng(51.2, lng),
      width: 40,
      height: 20,
      frames: frames,
      child: frames.first.child,
    );

    await tester.runAsync(() async {
      markers.update([walker(4.3)], wrap: wrap, pixelRatio: 1, ready: Future<void>.value());
      await Future<void>.delayed(const Duration(milliseconds: 1000));
    });
    final icons = <gm.BitmapDescriptor>{for (final update in updates) update.single.icon};
    // Alle drie de beelden zijn al getoond, telkens als nieuwe afbeelding.
    expect(icons, hasLength(3));

    // Franky wandelt verder: de plaats volgt, de animatie loopt door.
    final before = updates.length;
    await tester.runAsync(() async {
      markers.update([walker(4.301)], wrap: wrap, pixelRatio: 1, ready: Future<void>.value());
      await Future<void>.delayed(const Duration(milliseconds: 300));
    });
    expect(updates.length, greaterThan(before + 2));
    expect(updates.last.single.position.longitude, 4.301);
    expect(icons, contains(updates.last.single.icon));

    // Gestopt met wandelen: geen animatie meer, geen updates meer.
    await tester.runAsync(() async {
      markers.update(const [], wrap: wrap, pixelRatio: 1, ready: Future<void>.value());
      await Future<void>.delayed(const Duration(milliseconds: 400));
    });
    final stopped = updates.length;
    expect(updates.last, isEmpty);
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 300)));
    expect(updates.length, stopped);
  });

  testWidgets('ballon die van kant wisselt bevriest niet en hergebruikt zijn eerdere beeld', (tester) async {
    late Widget Function(Widget) wrap;
    var drawings = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) {
            final original = wrapForBitmap(context);
            wrap = (child) {
              drawings++;
              return original(child);
            };
            return const SizedBox();
          },
        ),
      ),
    );
    final updates = <Set<gm.Marker>>[];
    final markers = GoogleMemberMarkers(onChanged: updates.add);
    addTearDown(markers.dispose);
    MapMarkerSpec bubble(double lng, {required bool right}) => MapMarkerSpec(
      id: 'bubble_Franky',
      point: LatLng(51, lng),
      width: 142,
      height: 48,
      alignment: Alignment(right ? 1 : -1, -1),
      offset: Offset(right ? 20 : -20, -78),
      imageKey: right,
      // De staart spiegelt mee: ander beeld per kant.
      child: ColoredBox(color: right ? Colors.white : Colors.yellow),
    );
    Future<void> send(MapMarkerSpec spec, {int waitMs = 50}) async {
      markers.update([spec], wrap: wrap, pixelRatio: 1, ready: Future<void>.value());
      await Future<void>.delayed(Duration(milliseconds: waitMs));
    }

    await tester.runAsync(() async {
      await send(bubble(3, right: true), waitMs: 400);
      final rightIcon = updates.last.single.icon;
      final rightAnchor = updates.last.single.anchor;
      expect(drawings, 1);

      // Kant wissel: de plaats volgt meteen, nog met het vorige beeld.
      await send(bubble(3.001, right: false), waitMs: 10);
      expect(updates.last.single.position.longitude, 3.001);
      // Even later is het nieuwe beeld er.
      await send(bubble(3.002, right: false), waitMs: 400);
      expect(drawings, 2);
      expect(updates.last.single.icon, isNot(same(rightIcon)));
      expect(updates.last.single.anchor, isNot(rightAnchor));
      expect(updates.last.single.position.longitude, 3.002);

      // Terug naar rechts: meteen het bewaarde beeld, niets opnieuw getekend.
      await send(bubble(3.003, right: true), waitMs: 40);
      expect(updates.last.single.icon, same(rightIcon));
      expect(updates.last.single.anchor, rightAnchor);
      await Future<void>.delayed(const Duration(milliseconds: 300));
      expect(drawings, 2);
    });
  });

  testWidgets('gelijke inhoud en plaats: geen enkele tekening of update meer', (tester) async {
    late Widget Function(Widget) wrap;
    var drawings = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) {
            final original = wrapForBitmap(context);
            wrap = (child) {
              drawings++;
              return original(child);
            };
            return const SizedBox();
          },
        ),
      ),
    );
    final updates = <Set<gm.Marker>>[];
    final markers = GoogleMemberMarkers(onChanged: updates.add);
    addTearDown(markers.dispose);
    // Zoals de kaartlaag tijdens het scrollen: elk frame een nieuwe lijst.
    List<MapMarkerSpec> specs() => [
      const MapMarkerSpec(
        id: 'group_Franky',
        point: LatLng(51, 3),
        width: 60,
        height: 40,
        imageKey: 'Franky|Liam',
        child: ColoredBox(color: Colors.blue),
      ),
    ];
    await tester.runAsync(() async {
      for (var i = 0; i < 30; i++) {
        markers.update(specs(), wrap: wrap, pixelRatio: 1, ready: Future<void>.value());
        await Future<void>.delayed(const Duration(milliseconds: 30));
      }
      await Future<void>.delayed(const Duration(milliseconds: 300));
    });
    expect(drawings, 1);
    expect(updates, hasLength(1));
  });

  testWidgets('ballon die enkele pixels uitschuift: zelfde beeld, maar het anker schuift mee', (
    tester,
  ) async {
    late Widget Function(Widget) wrap;
    var drawings = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) {
            final original = wrapForBitmap(context);
            wrap = (child) {
              drawings++;
              return original(child);
            };
            return const SizedBox();
          },
        ),
      ),
    );
    final updates = <Set<gm.Marker>>[];
    final markers = GoogleMemberMarkers(onChanged: updates.add);
    addTearDown(markers.dispose);
    // Een ballon rechts van het lid, zoals de kaartlaag hem maakt, met [shiftX]
    // pixels uitschuiven. Tot een paar pixels naar links blijft de afbeelding
    // even groot en gelijk; enkel het anker verandert.
    MapMarkerSpec bubble(double shiftX) => MapMarkerSpec(
      id: 'bubble_Franky',
      point: const LatLng(51, 3),
      width: 142,
      height: 48,
      alignment: Alignment(1 + 2 * shiftX / 142, -1),
      offset: const Offset(20, -78),
      imageKey: 'Werk',
      child: const ColoredBox(color: Colors.white),
    );
    Offset anchorOf(double shiftX) => nativeMarkerFrame(
      size: const Size(142, 48),
      alignX: 1 + 2 * shiftX / 142,
      alignY: -1,
      offset: const Offset(20, -78),
      margin: 24,
    ).anchor;
    expect(anchorOf(-20), isNot(anchorOf(0)), reason: 'de test moet een echte verschuiving tonen');

    await tester.runAsync(() async {
      markers.update([bubble(-20)], wrap: wrap, pixelRatio: 1, ready: Future<void>.value());
      await Future<void>.delayed(const Duration(milliseconds: 400));
      markers.update([bubble(0)], wrap: wrap, pixelRatio: 1, ready: Future<void>.value());
      await Future<void>.delayed(const Duration(milliseconds: 400));
    });
    expect(drawings, 1, reason: 'zelfde beeld, dus niet opnieuw getekend');
    final anchor = updates.last.single.anchor;
    expect(anchor.dx, closeTo(anchorOf(0).dx, 1e-9), reason: 'de ballon blijft vast aan zijn lid');
    expect(anchor.dy, closeTo(anchorOf(0).dy, 1e-9));
  });
}
