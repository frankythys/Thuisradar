import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:thuisradar/core/theme/app_colors.dart';
import 'package:thuisradar/core/theme/app_theme.dart';
import 'package:thuisradar/features/family/domain/family_member.dart';
import 'package:thuisradar/features/location/domain/member_location.dart';
import 'package:thuisradar/features/map/domain/member_on_map.dart';
import 'package:thuisradar/features/map/presentation/widgets/clustered_marker_layer.dart';
import 'package:thuisradar/features/map/presentation/widgets/group_pin.dart';
import 'package:thuisradar/features/map/presentation/widgets/member_marker.dart';
import 'package:thuisradar/shared/widgets/member_avatar.dart';

void main() {
  final now = DateTime(2026, 10, 5, 12);
  MemberOnMap member(String id) => MemberOnMap(
    member: FamilyMember(userId: id, displayName: id, isOwner: false, colorIndex: 0),
    location: MemberLocation(
      userId: id,
      familyId: 'family',
      latitude: 51,
      longitude: 3,
      updatedAt: now,
      speedMps: 0,
    ),
  );

  testWidgets('stilstaand lid houdt infolabel zonder selectie of geschiedeniscallback', (tester) async {
    var opened = false;
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        home: Scaffold(
          body: FlutterMap(
            options: const MapOptions(initialCenter: LatLng(51, 3), initialZoom: 16),
            children: [
              ClusteredMarkerLayer(
                members: [member('Franky')],
                now: now,
                onMemberTap: (_) => opened = true,
                onGroupTap: (_) {},
              ),
            ],
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Stilstaand'), findsOneWidget);
    await tester.tap(find.text('Stilstaand'));
    expect(opened, isTrue);
    expect(tester.takeException(), isNull);
  });

  testWidgets('grote geselecteerde avatar gebruikt gereserveerde rand zonder wit', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        home: Scaffold(
          body: Center(
            child: SizedBox(
              width: MemberMarker.width,
              height: MemberMarker.height,
              child: MemberMarker(entry: member('Franky'), now: now, selected: true),
            ),
          ),
        ),
      ),
    );
    final avatar = tester.widget<MemberAvatar>(find.byType(MemberAvatar));
    expect(avatar.size, MemberMarker.avatarSize);
    expect(avatar.ring, isFalse);
    expect(AppColors.members, isNot(contains(AppColors.mapSelection)));
    expect(
      find.byWidgetPredicate(
        (widget) =>
            widget is Container &&
            widget.decoration is BoxDecoration &&
            (widget.decoration! as BoxDecoration).color == AppColors.mapSelection,
      ),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('tik op een avatar in de groep toont dat lid', (tester) async {
    MemberOnMap? tapped;
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        home: Scaffold(
          body: Center(
            child: SizedBox(
              width: GroupPin.width,
              height: GroupPin.height,
              child: GroupPin(
                members: [member('Franky'), member('Liam')],
                now: now,
                onMemberTap: (m) => tapped = m,
              ),
            ),
          ),
        ),
      ),
    );
    // De voorste avatar (index 0) ligt bovenop en komt als laatste in de boom.
    await tester.tap(find.byType(MemberAvatar).last);
    expect(tapped?.member.userId, 'Franky');
    expect(tester.takeException(), isNull);
  });

  testWidgets('groepspin met grote avatars en extra leden past in marker', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        home: Scaffold(
          body: Center(
            child: SizedBox(
              width: GroupPin.width,
              height: GroupPin.height,
              child: GroupPin(
                members: [member('Franky'), member('Liam'), member('Hedwig'), member('F')],
                now: now,
                selectedUserId: 'Franky',
              ),
            ),
          ),
        ),
      ),
    );
    expect(find.text('+1'), findsOneWidget);
    expect(
      tester.widgetList<MemberAvatar>(find.byType(MemberAvatar)).every((avatar) => avatar.size == 72),
      isTrue,
    );
    expect(tester.takeException(), isNull);
  });
}
