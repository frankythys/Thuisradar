import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:thuisradar/core/theme/app_theme.dart';
import 'package:thuisradar/features/family/domain/family_member.dart';
import 'package:thuisradar/features/location/domain/member_location.dart';
import 'package:thuisradar/features/map/domain/member_on_map.dart';
import 'package:thuisradar/features/map/presentation/widgets/clustered_marker_layer.dart';
import 'package:thuisradar/features/map/presentation/widgets/group_pin.dart';

void main() {
  testWidgets('het puntje van een groepspin staat op de locatie, niet eronder', (tester) async {
    const spot = LatLng(51.0, 4.0); // geen opgeslagen plaats in de buurt
    final now = DateTime(2026, 10, 10, 13);
    MemberOnMap member(String id) => MemberOnMap(
      member: FamilyMember(userId: id, displayName: id, isOwner: false, colorIndex: 0),
      location: MemberLocation(
        userId: id,
        familyId: 'f',
        latitude: spot.latitude,
        longitude: spot.longitude,
        updatedAt: now,
        speedMps: 0,
      ),
    );
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        home: Scaffold(
          body: FlutterMap(
            options: const MapOptions(initialCenter: spot, initialZoom: 15),
            children: [
              ClusteredMarkerLayer(
                members: [member('A'), member('B')],
                now: now,
                onMemberTap: (_) {},
                onGroupTap: (_) {},
              ),
            ],
          ),
        ),
      ),
    );
    await tester.pump(const Duration(seconds: 3));

    final location = tester.getCenter(find.byType(FlutterMap));
    final pin = tester.getRect(find.byType(GroupPin));
    // De pin hangt boven de plek: zijn onderkant (met het puntje) raakt de
    // locatie, binnen een paar pixels.
    expect(pin.bottom, closeTo(location.dy, 4));
    expect(pin.center.dx, closeTo(location.dx, 4));
  });
}
