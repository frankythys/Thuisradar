import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:mocktail/mocktail.dart';
import 'package:thuisradar/features/map/presentation/widgets/family_map.dart';
import 'package:thuisradar/features/map/presentation/widgets/google_base_map.dart';
import 'package:thuisradar/shared/widgets/app_map_tiles.dart';

class _Context extends Mock implements BuildContext {}

void main() {
  late MapController controller;

  setUp(() {
    controller = MapController();
    addTearDown(controller.dispose);
  });

  FamilyMap familyMap({required bool google, bool satellite = false}) => FamilyMap(
    controller: controller,
    members: const [],
    now: DateTime(2026),
    onMemberTap: (_) {},
    onGroupTap: (_) {},
    useGoogleMaps: google,
    satellite: satellite,
    bottomInset: 280,
  );

  test('vlag uit (standaard): gewone OpenStreetMap-kaart zoals voorheen', () {
    final map = familyMap(google: false).build(_Context()) as FlutterMap;
    expect(map.children.whereType<AppMapTiles>(), hasLength(1));
    expect(map.options.backgroundColor, const MapOptions().backgroundColor);
  });

  test('vlag aan: Google eronder, doorzichtige kaart met markers erboven', () {
    final stack = familyMap(google: true, satellite: true).build(_Context()) as Stack;
    final google = (stack.children.first as Positioned).child as GoogleBaseMap;
    final map = stack.children.last as FlutterMap;

    expect(google.satellite, isTrue);
    expect(google.bottomPadding, 280);
    expect(google.initialCenter, FamilyMap.fallbackCenter);
    expect(google.initialZoom, map.options.initialZoom);
    expect(map.options.initialCenter, const LatLng(50.85, 4.35));
    expect(map.options.backgroundColor, Colors.transparent);
    expect(map.children.whereType<AppMapTiles>(), isEmpty);
  });
}
