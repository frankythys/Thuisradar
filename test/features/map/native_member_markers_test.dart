import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:thuisradar/core/theme/app_theme.dart';
import 'package:thuisradar/features/family/domain/family_member.dart';
import 'package:thuisradar/features/location/domain/member_location.dart';
import 'package:thuisradar/features/map/domain/member_on_map.dart';
import 'package:thuisradar/features/map/presentation/widgets/clustered_marker_layer.dart';
import 'package:thuisradar/features/map/presentation/widgets/map_marker_spec.dart';
import 'package:thuisradar/features/map/presentation/widgets/member_marker.dart';
import 'package:thuisradar/shared/widgets/member_avatar.dart';

void main() {
  final now = DateTime(2026, 10, 10, 9, 24);
  final franky = MemberOnMap(
    member: const FamilyMember(userId: 'Franky', displayName: 'Franky', isOwner: true, colorIndex: 0),
    location: MemberLocation(
      userId: 'Franky',
      familyId: 'gezin',
      latitude: 51,
      longitude: 3,
      updatedAt: now,
      speedMps: 0,
    ),
  );

  Future<List<MapMarkerSpec>> pumpNative(
    WidgetTester tester, {
    String? selected,
    ValueChanged<MemberOnMap>? onMemberTap,
  }) async {
    var specs = <MapMarkerSpec>[];
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        home: Scaffold(
          body: FlutterMap(
            options: const MapOptions(initialCenter: LatLng(51, 3), initialZoom: 17),
            children: [
              ClusteredMarkerLayer(
                members: [franky],
                now: now,
                selectedUserId: selected,
                onMemberTap: onMemberTap ?? (_) {},
                onGroupTap: (_) {},
                onNativeMarkers: (value) => specs = value,
              ),
            ],
          ),
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 100));
    return specs;
  }

  testWidgets('met Google: Franky en zijn ballon gaan naar Google, niets zichtbaars erboven', (tester) async {
    final specs = await pumpNative(tester);

    expect(specs.map((s) => s.id), containsAll(['member_Franky', 'bubble_Franky']));
    expect(specs.firstWhere((s) => s.id == 'member_Franky').point, const LatLng(51, 3));
    // De kaart erboven toont geen rondje meer: anders zou het meeglijden.
    expect(find.byType(MemberAvatar), findsNothing);
  });

  testWidgets('met Google: tik op Franky werkt via het onzichtbare tikvlak', (tester) async {
    MemberOnMap? tapped;
    final specs = await pumpNative(tester, onMemberTap: (m) => tapped = m);
    expect(specs, isNotEmpty);

    // Het rondje hangt als pin boven het punt (midden van het scherm).
    final center = tester.getCenter(find.byType(FlutterMap));
    await tester.tapAt(center - const Offset(0, MemberMarker.height - MemberMarker.avatarSize / 2));
    await tester.pump(const Duration(milliseconds: 100));

    expect(tapped?.member.userId, 'Franky');
  });
}
