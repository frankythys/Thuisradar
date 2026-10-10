import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:mocktail/mocktail.dart';
import 'package:thuisradar/features/map/presentation/widgets/family_map.dart';
import 'package:thuisradar/features/map/presentation/widgets/clustered_marker_layer.dart';
import 'package:thuisradar/features/map/presentation/widgets/google_base_map.dart';
import 'package:thuisradar/features/map/presentation/widgets/google_map_stack.dart';
import 'package:thuisradar/features/map/presentation/widgets/map_marker_spec.dart';
import 'package:thuisradar/features/places/domain/place.dart';
import 'package:thuisradar/shared/widgets/app_map_tiles.dart';

class _Context extends Mock implements BuildContext {}

void main() {
  late MapController controller;

  setUp(() {
    controller = MapController();
    addTearDown(controller.dispose);
  });

  const thuis = Place(
    id: 'thuis',
    familyId: 'f1',
    name: 'Thuis',
    latitude: 51.0,
    longitude: 4.0,
    radiusMeters: 150,
    icon: 'home',
  );

  FamilyMap familyMap({required bool google, bool satellite = false}) => FamilyMap(
    controller: controller,
    members: const [],
    places: const [thuis],
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
    expect(map.children.whereType<CircleLayer>(), hasLength(1));
    expect(map.options.backgroundColor, const MapOptions().backgroundColor);
    expect(map.options.maxZoom, 18);
  });

  ({GoogleBaseMap google, FlutterMap map}) googleParts({bool satellite = false}) {
    final stack = familyMap(google: true, satellite: satellite).build(_Context()) as GoogleMapStack;
    return (
      google: stack.base(ValueNotifier<List<MapMarkerSpec>>(const [])) as GoogleBaseMap,
      map: stack.overlay((_) {}) as FlutterMap,
    );
  }

  test('vlag aan: Google eronder, doorzichtige kaart met tikvlakken erboven', () {
    final (:google, :map) = googleParts(satellite: true);

    expect(google.satellite, isTrue);
    expect(google.bottomPadding, 280);
    expect(google.initialCenter, FamilyMap.fallbackCenter);
    expect(google.initialZoom, map.options.initialZoom);
    expect(google.markers, isNotNull);
    expect(map.options.initialCenter, const LatLng(50.85, 4.35));
    expect(map.options.backgroundColor, Colors.transparent);
    // Zoals in Google Maps zelf: verder inzoomen dan 18 kan.
    expect(map.options.maxZoom, 21);
    expect(map.children.whereType<AppMapTiles>(), isEmpty);
  });

  test('vlag aan: Thuis en de gezinsleden tekent Google, dus niets glijdt mee bij scrollen', () {
    final (:google, :map) = googleParts();

    expect(google.places.single.id, 'thuis');
    expect(map.children.whereType<CircleLayer>(), isEmpty);
    expect(map.children.whereType<MarkerLayer>(), isEmpty);
    expect(map.children.whereType<ClusteredMarkerLayer>().single.onNativeMarkers, isNotNull);
  });
}
