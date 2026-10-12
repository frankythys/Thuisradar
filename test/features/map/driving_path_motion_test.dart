import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:thuisradar/features/family/domain/family_member.dart';
import 'package:thuisradar/features/location/domain/member_location.dart';
import 'package:thuisradar/features/map/domain/member_on_map.dart';
import 'package:thuisradar/features/map/domain/road_matching.dart';
import 'package:thuisradar/features/map/domain/road_motion_path.dart';
import 'package:thuisradar/features/map/presentation/widgets/clustered_marker_layer.dart';
import 'package:thuisradar/features/map/presentation/widgets/map_marker_spec.dart';

import 'road_matching_test.dart' show point;

class _Map {
  final controller = MapController();
  final now = DateTime(2026, 10, 12, 12);
  var markers = <MapMarkerSpec>[];
  MemberOnMap car(String id, RoadPoint point, int second, {List<RoadPoint>? path}) => MemberOnMap(
    member: FamilyMember(userId: id, displayName: id, isOwner: false, colorIndex: 0),
    location: MemberLocation(
      userId: id,
      familyId: 'f',
      latitude: point.lat,
      longitude: point.lng,
      updatedAt: now.add(Duration(seconds: second)),
      speedMps: 15,
    ),
    roadPath: path,
  );
  Future<void> show(WidgetTester tester, List<MemberOnMap> members) async {
    await tester.pumpWidget(
      MaterialApp(
        home: FlutterMap(
          mapController: controller,
          options: const MapOptions(initialCenter: LatLng(0, 0), initialZoom: 16),
          children: [
            ClusteredMarkerLayer(
              members: members,
              now: now,
              onMemberTap: (_) {},
              onGroupTap: (_) {},
              onNativeMarkers: (value) => markers = value,
            ),
          ],
        ),
      ),
    );
    await tester.pump();
  }

  RoadPoint shown(String id) {
    final coordinate = markers.firstWhere((m) => m.id == 'member_$id').point;
    return (lat: coordinate.latitude, lng: coordinate.longitude);
  }

  Future<void> close(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox());
    controller.dispose();
  }
}

void main() {
  testWidgets('auto blijft tijdens de hele bocht op de weg', (tester) async {
    final map = _Map();
    final a = point(0, 0), corner = point(50, 0), b = point(50, 50);
    await map.show(tester, [map.car('car', a, 0)]);
    await map.show(tester, [
      map.car('car', b, 5, path: [a, corner, b]),
    ]);
    for (var i = 0; i < 20; i++) {
      await tester.pump(const Duration(milliseconds: 250));
      final current = map.shown('car');
      expect(
        current.lat.abs() < 1e-8 || (current.lng - corner.lng).abs() < 1e-8,
        isTrue,
        reason: 'De marker mag nergens over de diagonaal van de bocht bewegen.',
      );
    }
    expect(roadDistance(map.shown('car'), b), lessThan(.01));
    await map.close(tester);
  });
  testWidgets('late wegvorm voor hetzelfde eindpunt wordt alsnog toegepast', (tester) async {
    final map = _Map();
    final a = point(0, 0), corner = point(50, 0), b = point(50, 50);
    await map.show(tester, [map.car('car', a, 0)]);
    await map.show(tester, [map.car('car', b, 5)]);
    await tester.pump(const Duration(milliseconds: 50));
    final before = map.shown('car');
    await map.show(tester, [
      map.car('car', b, 5, path: [a, corner, b]),
    ]);
    expect(roadDistance(map.shown('car'), before), lessThan(.01));
    await tester.pump(const Duration(seconds: 1));
    expect(map.shown('car').lat.abs(), lessThan(1e-8));
    await tester.pump(const Duration(seconds: 4));
    expect(roadDistance(map.shown('car'), b), lessThan(.01));
    await map.close(tester);
  });
  testWidgets('update van een ander lid vertraagt de eerste auto niet', (tester) async {
    final map = _Map();
    final a0 = point(0, 0), a1 = point(100, 0), b0 = point(0, 200), b1 = point(100, 200);
    await map.show(tester, [map.car('a', a0, 0), map.car('b', b0, 0)]);
    await map.show(tester, [map.car('a', a1, 5), map.car('b', b0, 0)]);
    await tester.pump(const Duration(seconds: 2));
    expect(roadDistance(map.shown('a'), point(40, 0)), lessThan(.01));
    await map.show(tester, [map.car('a', a1, 5), map.car('b', b1, 5)]);
    expect(roadDistance(map.shown('a'), point(40, 0)), lessThan(.01));
    await tester.pump(const Duration(seconds: 3));
    expect(roadDistance(map.shown('a'), a1), lessThan(.01));
    expect(roadDistance(map.shown('b'), point(60, 200)), lessThan(.01));
    await map.close(tester);
  });
}
