import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:mocktail/mocktail.dart';
import 'package:thuisradar/features/map/presentation/widgets/google_base_map.dart';
import 'package:thuisradar/features/places/presentation/place_edit_map.dart';
import 'package:thuisradar/shared/widgets/app_map_tiles.dart';

class _Context extends Mock implements BuildContext {}

void main() {
  late MapController controller;

  setUp(() {
    controller = MapController();
    addTearDown(controller.dispose);
  });

  PlaceEditMap placeMap({required bool google}) => PlaceEditMap(
    controller: controller,
    center: const LatLng(51.0, 4.0),
    radiusMeters: 150,
    onPositionChanged: (_, _) {},
    useGoogleMaps: google,
  );

  test('vlag uit: OpenStreetMap-tegels met naamsvermelding, zoom tot 19', () {
    final map = placeMap(google: false).build(_Context()) as FlutterMap;

    expect(map.children.whereType<AppMapTiles>(), hasLength(1));
    expect(
      map.children.whereType<Align>().map((a) => (a.child! as Padding).child),
      contains(isA<Text>().having((t) => t.data, 'tekst', '© OpenStreetMap-bijdragers')),
    );
    expect(map.children.whereType<CircleLayer>(), hasLength(1));
    expect(map.options.maxZoom, 19);
  });

  test('vlag aan: Google Maps eronder, zelfde camera, doorzichtige kaart erboven', () {
    final stack = placeMap(google: true).build(_Context()) as Stack;
    final google = (stack.children.first as Positioned).child as GoogleBaseMap;
    final map = stack.children.last as FlutterMap;

    expect(google.controller, same(controller));
    expect(google.initialCenter, const LatLng(51.0, 4.0));
    expect(google.initialZoom, map.options.initialZoom);
    expect(map.children.whereType<AppMapTiles>(), isEmpty);
    expect(map.children.whereType<Align>(), isEmpty);
    // De straal blijft zichtbaar boven Google.
    expect(map.children.whereType<CircleLayer>(), hasLength(1));
    expect(map.options.backgroundColor, Colors.transparent);
    expect(map.options.maxZoom, 21);
  });

  test('zonder straal (parkeerplek): geen cirkel, wel dichter ingezoomd', () {
    final map = PlaceEditMap(
      controller: controller,
      center: const LatLng(51.0, 4.0),
      radiusMeters: 0,
      initialZoom: 18,
      onPositionChanged: (_, _) {},
      useGoogleMaps: false,
    ).build(_Context()) as FlutterMap;

    expect(map.children.whereType<CircleLayer>(), isEmpty);
    expect(map.options.initialZoom, 18);
  });
}
