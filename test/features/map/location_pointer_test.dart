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
import 'package:thuisradar/shared/widgets/member_avatar.dart';

void main() {
  // Franky wandelt op de Berkenlaan (Antwerpen).
  const berkenlaan = LatLng(51.1765, 4.4122);
  final now = DateTime(2026, 10, 10, 9, 54);

  Future<void> pumpFranky(WidgetTester tester, {double speedMps = 1.2, bool selected = false}) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        home: Scaffold(
          body: FlutterMap(
            options: const MapOptions(initialCenter: berkenlaan, initialZoom: 19, maxZoom: 21),
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
                      latitude: berkenlaan.latitude,
                      longitude: berkenlaan.longitude,
                      updatedAt: now,
                      speedMps: speedMps,
                    ),
                  ),
                ],
                now: now,
                selectedUserId: selected ? 'Franky' : null,
                onMemberTap: (_) {},
                onGroupTap: (_) {},
              ),
            ],
          ),
        ),
      ),
    );
    await tester.pump(const Duration(seconds: 3));
  }

  testWidgets('wandelend op de Berkenlaan: stip exact op zijn locatie, puntje wijst ernaartoe', (
    tester,
  ) async {
    await pumpFranky(tester);
    final location = tester.getCenter(find.byType(FlutterMap));

    // De stip ligt precies op het GPS-punt (midden van de kaart).
    final dot = tester.getCenter(find.byType(LocationDot));
    expect(dot.dx, closeTo(location.dx, 0.5));
    expect(dot.dy, closeTo(location.dy, 0.5));

    // Het puntje zit onder het rondje, recht boven de stip en raakt de halo.
    final tail = tester.getRect(find.byType(MarkerTail));
    final avatar = tester.getRect(find.byType(MemberAvatar));
    expect(tail.center.dx, closeTo(location.dx, 0.5));
    expect(tail.top, closeTo(avatar.bottom, 0.5));
    expect(tail.bottom, greaterThanOrEqualTo(location.dy - LocationDot.haloSize / 2));
    expect(tail.bottom, lessThan(location.dy - LocationDot.dotSize / 2));
  });

  testWidgets('geselecteerd: paars puntje raakt ook de stip', (tester) async {
    await pumpFranky(tester, selected: true);
    final location = tester.getCenter(find.byType(FlutterMap));
    final tail = tester.getRect(find.byType(MarkerTail));
    expect(tail.center.dx, closeTo(location.dx, 0.5));
    expect(tail.bottom, greaterThanOrEqualTo(location.dy - LocationDot.haloSize / 2));
    expect(tail.bottom, lessThan(location.dy - LocationDot.dotSize / 2));
  });

  testWidgets('rijdend: rondje gecentreerd op de weg, zonder puntje of stip', (tester) async {
    await pumpFranky(tester, speedMps: 14);
    expect(find.byType(MarkerTail), findsNothing);
    expect(find.byType(LocationDot), findsNothing);
  });
}
