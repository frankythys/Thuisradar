import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:thuisradar/features/family/domain/family_member.dart';
import 'package:thuisradar/features/location/domain/member_location.dart';
import 'package:thuisradar/features/map/domain/member_on_map.dart';
import 'package:thuisradar/features/map/domain/driving_follow.dart';
import 'package:thuisradar/features/map/presentation/widgets/clustered_marker_layer.dart';
import 'package:thuisradar/features/map/presentation/widgets/map_marker_spec.dart';

void main() {
  testWidgets('auto blijft bewegen tussen normale GPS-updates van vijf seconden', (tester) async {
    final controller = MapController();
    final now = DateTime(2026, 10, 12, 12);
    var markers = <MapMarkerSpec>[];
    Future<void> show(double longitude, int seconds) => tester.pumpWidget(
      MaterialApp(
        home: FlutterMap(
          mapController: controller,
          options: const MapOptions(initialCenter: LatLng(51, 3), initialZoom: 16),
          children: [
            ClusteredMarkerLayer(
              members: [
                MemberOnMap(
                  member: const FamilyMember(
                    userId: 'car',
                    displayName: 'Auto',
                    isOwner: false,
                    colorIndex: 0,
                  ),
                  location: MemberLocation(
                    userId: 'car',
                    familyId: 'f',
                    latitude: 51,
                    longitude: longitude,
                    updatedAt: now.add(Duration(seconds: seconds)),
                    speedMps: 15,
                  ),
                ),
              ],
              now: now,
              onMemberTap: (_) {},
              onGroupTap: (_) {},
              onNativeMarkers: (value) => markers = value,
            ),
          ],
        ),
      ),
    );
    double longitude() => markers.firstWhere((m) => m.id == 'member_car').point.longitude;
    await show(3, 0);
    await show(3.001, 5);
    await tester.pump();
    await tester.pump(const Duration(seconds: 2));
    expect(longitude(), closeTo(3.0004, .000001));
    await tester.pump(const Duration(milliseconds: 2900));
    expect(longitude(), closeTo(3.00098, .000001));
    await show(3.002, 10);
    await tester.pump();
    expect(longitude(), closeTo(3.00098, .000001));
    await tester.pump(const Duration(seconds: 1));
    expect(longitude(), greaterThan(3.00098));
    await tester.pumpWidget(const SizedBox());
    controller.dispose();
  });

  testWidgets('auto beweegt door tijdens inzoomen en nieuwe locatie', (tester) async {
    final controller = MapController();
    final now = DateTime(2026, 10, 12, 12);
    var markers = <MapMarkerSpec>[];
    MemberOnMap car(double longitude, int seconds) => MemberOnMap(
      member: const FamilyMember(userId: 'car', displayName: 'Car', isOwner: false, colorIndex: 0),
      location: MemberLocation(
        userId: 'car',
        familyId: 'family',
        latitude: 51,
        longitude: longitude,
        updatedAt: now.add(Duration(seconds: seconds)),
        speedMps: 15,
      ),
    );
    Future<void> show(double longitude, int seconds) => tester.pumpWidget(
      MaterialApp(
        home: FlutterMap(
          mapController: controller,
          options: const MapOptions(initialCenter: LatLng(51, 3), initialZoom: 16),
          children: [
            ClusteredMarkerLayer(
              members: [car(longitude, seconds)],
              now: now,
              selectedUserId: 'car',
              onDrivingFrame: (id, point, bearing) {
                final camera = controller.camera;
                final heading = bearing ?? 0;
                controller.moveAndRotate(
                  drivingCameraCenter(point, heading, camera.zoom, camera.nonRotatedSize.height, 100),
                  camera.zoom,
                  -heading,
                );
              },
              onMemberTap: (_) {},
              onGroupTap: (_) {},
              onNativeMarkers: (value) => markers = value,
            ),
          ],
        ),
      ),
    );
    double longitude() => markers.firstWhere((m) => m.id == 'member_car').point.longitude;

    await show(3, 0);
    await show(3.001, 2);
    await tester.pump();
    expect(longitude(), 3);
    await tester.pump(const Duration(milliseconds: 500));
    expect(longitude(), closeTo(3.00025, 0.000001));
    controller.move(const LatLng(51, 3), 20);
    await tester.pump();
    expect(longitude(), closeTo(3.00025, 0.000001));
    await tester.pump(const Duration(milliseconds: 500));
    expect(longitude(), closeTo(3.0005, 0.000001));
    expect(controller.camera.zoom, 20);
    expect(controller.camera.rotation, closeTo(-90, .01));
    await show(3.002, 4);
    await tester.pump();
    expect(longitude(), closeTo(3.0005, 0.000001));
    await tester.pump(const Duration(seconds: 2));
    expect(longitude(), closeTo(3.002, 0.000001));
    await tester.pumpAndSettle();
    await tester.pumpWidget(const SizedBox());
    controller.dispose();
  });
}
