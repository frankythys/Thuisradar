import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:mocktail/mocktail.dart';
import 'package:thuisradar/features/map/presentation/widgets/family_map.dart';
import 'package:thuisradar/features/map/presentation/widgets/map_gestures.dart';
import 'package:thuisradar/features/map/domain/member_on_map.dart';
import 'package:thuisradar/features/family/domain/family_member.dart';
import 'package:thuisradar/features/location/domain/member_location.dart';

class _Context extends Mock implements BuildContext {}

/// De kaart zelf, onder de laag die het draaien met twee vingers bewaakt.
FlutterMap _unwrap(Widget widget) => (widget as TwistToRotate).builder(_Context(), false) as FlutterMap;

void main() {
  test('begint direct bij de bekende eigen locatie', () {
    final controller = MapController();
    addTearDown(controller.dispose);
    final map = _unwrap(
      FamilyMap(
        controller: controller,
        members: [
          MemberOnMap(
            member: const FamilyMember(userId: 'me', displayName: 'Ik', isOwner: true, colorIndex: 0),
            location: MemberLocation(
              userId: 'me',
              familyId: 'fam',
              latitude: 51.2,
              longitude: 4.4,
              updatedAt: DateTime(2026),
            ),
          ),
        ],
        myUserId: 'me',
        now: DateTime(2026),
        onMemberTap: (_) {},
        onGroupTap: (_) {},
      ).build(_Context()),
    );
    expect(map.options.initialCenter, const LatLng(51.2, 4.4));
    expect(map.options.initialZoom, 12);
  });
  test('kaart kan aan beide kanten over de wereldrand schuiven', () {
    final controller = MapController();
    addTearDown(controller.dispose);
    final map = _unwrap(
      FamilyMap(
        controller: controller,
        members: const [],
        now: DateTime(2026),
        onMemberTap: (_) {},
        onGroupTap: (_) {},
      ).build(_Context()),
    );
    for (final longitude in [-179.0, 179.0]) {
      final camera = MapCamera.initialCamera(map.options)
          .withNonRotatedSize(const Size(800, 600))
          .withPosition(center: LatLng(0, longitude), zoom: 3);
      final constrained = map.options.cameraConstraint.constrain(camera);
      expect(constrained, isNotNull);
      expect(constrained!.center.longitude, longitude);
    }
  });
}
