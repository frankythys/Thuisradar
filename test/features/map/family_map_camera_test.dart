import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:mocktail/mocktail.dart';
import 'package:thuisradar/features/map/presentation/widgets/family_map.dart';

class _Context extends Mock implements BuildContext {}

void main() {
  test('kaart kan aan beide kanten over de wereldrand schuiven', () {
    final controller = MapController();
    addTearDown(controller.dispose);
    final map = FamilyMap(
      controller: controller,
      members: const [],
      now: DateTime(2026),
      onMemberTap: (_) {},
      onGroupTap: (_) {},
    ).build(_Context()) as FlutterMap;
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
