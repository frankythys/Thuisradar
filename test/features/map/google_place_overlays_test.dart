import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart' as gm;
import 'package:thuisradar/features/map/presentation/widgets/google_place_overlays.dart';
import 'package:thuisradar/features/places/domain/place.dart';

const _thuis = Place(
  id: 'thuis',
  familyId: 'f1',
  name: 'Thuis',
  latitude: 51.0,
  longitude: 4.0,
  radiusMeters: 150,
  icon: 'home',
);

const _werk = Place(
  id: 'werk',
  familyId: 'f1',
  name: 'Werk',
  latitude: 51.2,
  longitude: 4.4,
  radiusMeters: 200,
  icon: 'work',
);

void main() {
  test('Thuis: cirkel op de juiste plek met de juiste straal', () {
    final circle = placeCircles(const [_thuis], color: Colors.blue, pixelRatio: 2.625).single;
    expect(circle.center, const gm.LatLng(51.0, 4.0));
    expect(circle.radius, 150);
    expect(circle.strokeWidth, 4);
  });

  test('icoon gecentreerd op het middelpunt; plaats zonder getekend icoon even overslaan', () {
    final markers = placeMarkers(const [_thuis, _werk], {'home': gm.BitmapDescriptor.defaultMarker});
    final marker = markers.single;
    expect(marker.position, const gm.LatLng(51.0, 4.0));
    expect(marker.anchor, const Offset(0.5, 0.5));
  });

  testWidgets('huis-icoon wordt als bitmap getekend', (tester) async {
    final icon = await tester.runAsync(
      () => placeIconBitmap(Icons.home_rounded, color: Colors.blue, size: 20, pixelRatio: 2),
    );
    expect(icon, isA<gm.BytesMapBitmap>());
    expect((icon! as gm.BytesMapBitmap).byteData, isNotEmpty);
  });
}
