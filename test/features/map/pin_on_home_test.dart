import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:thuisradar/core/theme/app_theme.dart';
import 'package:thuisradar/features/family/domain/family_member.dart';
import 'package:thuisradar/features/location/domain/member_location.dart';
import 'package:thuisradar/features/map/domain/member_on_map.dart';
import 'package:thuisradar/features/map/presentation/widgets/clustered_marker_layer.dart';
import 'package:thuisradar/features/map/presentation/widgets/location_pointer.dart';

void main() {
  testWidgets('Franky alleen thuis: de stip van zijn rondje staat precies op het huis', (tester) async {
    // Pierebeekstraat: Thuis, met het huis-icoon op dezelfde plek.
    const home = LatLng(51.1765, 4.4122);
    final now = DateTime(2026, 10, 10, 13);
    for (final zoom in [15.0, 18.0, 20.0]) {
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light(),
          home: Scaffold(
            body: FlutterMap(
              options: MapOptions(initialCenter: home, initialZoom: zoom, maxZoom: 21),
              children: [
                ClusteredMarkerLayer(
                  members: [
                    MemberOnMap(
                      member: const FamilyMember(
                        userId: 'Franky',
                        displayName: 'Franky',
                        isOwner: true,
                        colorIndex: 0,
                      ),
                      location: MemberLocation(
                        userId: 'Franky',
                        familyId: 'gezin',
                        latitude: home.latitude,
                        longitude: home.longitude,
                        updatedAt: now,
                        speedMps: 0,
                      ),
                    ),
                  ],
                  now: now,
                  reservedPlaces: const [home],
                  onMemberTap: (_) {},
                  onGroupTap: (_) {},
                ),
              ],
            ),
          ),
        ),
      );
      await tester.pump(const Duration(seconds: 3));
      final house = tester.getCenter(find.byType(FlutterMap));
      final dot = tester.getCenter(find.byType(LocationDot));
      expect(dot.dx, closeTo(house.dx, 0.5), reason: 'zoom $zoom');
      expect(dot.dy, closeTo(house.dy, 0.5), reason: 'zoom $zoom');
    }
  });
}
