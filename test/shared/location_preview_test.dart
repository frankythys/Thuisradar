import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:thuisradar/shared/widgets/location_preview.dart';

void main() {
  testWidgets(
    'later geladen route past volledig in bestaande kaart en kan vergroot worden',
    (tester) async {
      const start = LatLng(51.2, 4.3);
      const end = LatLng(51.24, 4.44);
      Widget preview(List<LatLng> route) => MaterialApp(
        home: Scaffold(
          body: Center(
            child: SizedBox(
              width: 360,
              child: LocationPreview(
                latitude: end.latitude,
                longitude: end.longitude,
                height: 240,
                route: route,
                fitBounds: true,
                showMarker: false,
                allowFullscreen: true,
              ),
            ),
          ),
        ),
      );
      await tester.pumpWidget(preview([]));
      await tester.pumpAndSettle();
      final original = tester
          .widget<FlutterMap>(find.byType(FlutterMap))
          .mapController;
      await tester.pumpWidget(preview([start, end]));
      await tester.pumpAndSettle();
      final map = tester.widget<FlutterMap>(find.byType(FlutterMap));
      expect(map.mapController, same(original));
      final rect = Offset.zero & tester.getSize(find.byType(FlutterMap));
      for (final point in [start, end]) {
        expect(
          rect
              .deflate(18)
              .contains(map.mapController!.camera.latLngToScreenOffset(point)),
          isTrue,
        );
      }
      expect(map.options.interactionOptions.flags, InteractiveFlag.none);
      await tester.tap(find.byTooltip('Ritkaart vergroten'));
      await tester.pumpAndSettle();
      expect(find.text('Ritkaart'), findsOneWidget);
      final enlarged = tester.widget<FlutterMap>(find.byType(FlutterMap));
      expect(
        enlarged.options.interactionOptions.flags & InteractiveFlag.pinchZoom,
        isNot(0),
      );
      expect(tester.getSize(find.byType(FlutterMap)).height, greaterThan(240));
      expect(tester.takeException(), isNull);
    },
  );
}
