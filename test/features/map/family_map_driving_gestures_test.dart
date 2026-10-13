import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:mocktail/mocktail.dart';
import 'package:thuisradar/features/family/domain/family_member.dart';
import 'package:thuisradar/features/location/domain/member_location.dart';
import 'package:thuisradar/features/map/domain/member_on_map.dart';
import 'package:thuisradar/features/map/presentation/widgets/family_map.dart';
import 'package:thuisradar/features/map/presentation/widgets/google_map_stack.dart';
import 'package:thuisradar/features/map/presentation/widgets/map_marker_spec.dart';

class _Context extends Mock implements BuildContext {}

void main() {
  testWidgets('zoomen en slepen blijven werken tijdens rijden, zonder automatisch meeschuiven', (
    tester,
  ) async {
    final controller = MapController();
    var drags = 0;
    var markers = <MapMarkerSpec>[];
    final now = DateTime(2026, 10, 12, 12);
    Future<void> show(double lng, int seconds) async {
      final stack = FamilyMap(
        controller: controller,
        useGoogleMaps: true,
        myUserId: 'car',
        selectedUserId: 'car',
        members: [
          MemberOnMap(
            member: const FamilyMember(userId: 'car', displayName: 'Auto', isOwner: false, colorIndex: 0),
            location: MemberLocation(
              userId: 'car',
              familyId: 'f',
              latitude: 51,
              longitude: lng,
              updatedAt: now.add(Duration(seconds: seconds)),
              speedMps: 15,
            ),
          ),
        ],
        now: now,
        onMemberTap: (_) {},
        onGroupTap: (_) {},
        onUserGesture: () => drags++,
      ).build(_Context()) as GoogleMapStack;
      await tester.pumpWidget(MaterialApp(home: stack.overlay((value) => markers = value)));
      await tester.pump();
    }

    await show(3, 0);
    controller.move(const LatLng(51, 3), 16);
    await tester.pump();
    final center = controller.camera.center;
    await show(3.001, 5);
    await tester.pump(const Duration(milliseconds: 500));
    expect(controller.camera.center, center);
    expect(controller.camera.zoom, 16);
    expect(controller.camera.rotation, 0);
    final before = markers.firstWhere((m) => m.id == 'member_car').point.longitude;
    final first = await tester.createGesture(pointer: 1);
    final second = await tester.createGesture(pointer: 2);
    await first.down(const Offset(250, 150));
    await second.down(const Offset(350, 150));
    await tester.pump();
    await first.moveTo(const Offset(230, 150));
    await second.moveTo(const Offset(370, 150));
    await tester.pump(const Duration(milliseconds: 100));
    await first.moveTo(const Offset(200, 150));
    await second.moveTo(const Offset(400, 150));
    await tester.pump(const Duration(milliseconds: 100));
    await first.up();
    await second.up();
    await tester.pump();
    expect(drags, 0);
    expect(controller.camera.zoom, greaterThan(16));
    expect(markers.firstWhere((m) => m.id == 'member_car').point.longitude, greaterThan(before));
    final zoomedCenter = controller.camera.center;
    final zoom = controller.camera.zoom;
    await tester.pump(const Duration(seconds: 1));
    expect(controller.camera.center, zoomedCenter);
    expect(controller.camera.zoom, zoom);
    expect(controller.camera.rotation, 0);
    await tester.dragFrom(const Offset(100, 100), const Offset(100, 0));
    await tester.pump();
    expect(drags, greaterThan(0));
    await tester.pumpWidget(const SizedBox());
    controller.dispose();
  });
}
