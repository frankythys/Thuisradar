import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:thuisradar/core/theme/app_theme.dart';
import 'package:thuisradar/features/family/domain/family_member.dart';
import 'package:thuisradar/features/location/domain/member_location.dart';
import 'package:thuisradar/features/map/domain/member_on_map.dart';
import 'package:thuisradar/features/map/presentation/widgets/offscreen_members_layer.dart';
import 'package:thuisradar/shared/widgets/member_avatar.dart';

void main() {
  const center = LatLng(51.0, 4.0);
  final now = DateTime(2026, 10, 22, 12);
  MemberOnMap member(String id, LatLng at) => MemberOnMap(
    member: FamilyMember(userId: id, displayName: id, isOwner: false, colorIndex: 0),
    location: MemberLocation(
      userId: id,
      familyId: 'f',
      latitude: at.latitude,
      longitude: at.longitude,
      updatedAt: now,
      speedMps: 20,
    ),
  );

  Future<void> pump(WidgetTester tester, List<MemberOnMap> members, ValueChanged<MemberOnMap> onTap) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        home: Scaffold(
          body: FlutterMap(
            options: const MapOptions(initialCenter: center, initialZoom: 15),
            children: [
              OffscreenMembersLayer(members: members, myUserId: 'ik', bottomInset: 200, onTap: onTap),
            ],
          ),
        ),
      ),
    );
    await tester.pump();
  }

  testWidgets('wie wegrijdt, krijgt een pijl aan de rand; wie in beeld is en jijzelf niet', (tester) async {
    MemberOnMap? tapped;
    await pump(
      tester,
      [
        member('ik', const LatLng(51.2, 4.0)), // ook buiten beeld, maar dat ben jij
        member('Liam', const LatLng(51.0, 4.3)), // ver naar het oosten
        member('Hedwig', center), // in beeld
      ],
      (m) => tapped = m,
    );

    final avatars = tester.widgetList<MemberAvatar>(find.byType(MemberAvatar)).toList();
    expect(avatars.map((a) => a.member.userId), ['Liam']);

    // Rechts aan de rand, boven het onderpaneel.
    final screen = tester.getRect(find.byType(FlutterMap));
    final arrow = tester.getCenter(find.byType(MemberAvatar));
    expect(arrow.dx, greaterThan(screen.right - OffscreenMembersLayer.circle * 1.5));
    expect(arrow.dy, inExclusiveRange(screen.top, screen.bottom - 200));

    await tester.tap(find.byType(MemberAvatar));
    expect(tapped?.member.userId, 'Liam');
    expect(tester.takeException(), isNull);
  });

  testWidgets('wie achter het onderpaneel staat, krijgt een pijl erboven', (tester) async {
    await pump(tester, [member('Liam', const LatLng(50.995, 4.0))], (_) {});
    final screen = tester.getRect(find.byType(FlutterMap));
    final arrow = tester.getCenter(find.byType(MemberAvatar));
    expect(arrow.dy, lessThan(screen.bottom - 200));
  });
}
