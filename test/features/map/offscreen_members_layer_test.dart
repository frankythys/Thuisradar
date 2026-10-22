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

  // Kaart van 800 × 600: paneel 200 hoog, knoppen rechts van 216 tot 444 boven de onderkant.
  MapCover cover({double sheet = 200}) => (sheet: sheet, buttonsWidth: 64, buttonsBottom: 216, buttonsTop: 444);

  Future<void> pump(
    WidgetTester tester,
    List<MemberOnMap> members, {
    ValueChanged<MemberOnMap>? onTap,
    ValueNotifier<double>? sheet,
  }) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        home: Scaffold(
          body: FlutterMap(
            options: const MapOptions(initialCenter: center, initialZoom: 15),
            children: [
              OffscreenMembersLayer(
                members: members,
                cover: () => cover(sheet: sheet?.value ?? 200),
                coverChanges: sheet,
                onTap: onTap ?? (_) {},
              ),
            ],
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  Rect arrowOf(WidgetTester tester, String id) => tester.getRect(
    find.byWidgetPredicate((widget) => widget is MemberAvatar && widget.member.userId == id),
  );

  testWidgets('iedereen buiten beeld krijgt een pijl, ook jijzelf; wie in beeld is niet', (tester) async {
    MemberOnMap? tapped;
    await pump(
      tester,
      [
        member('ik', const LatLng(51.2, 4.0)), // ver naar het noorden
        member('Liam', const LatLng(51.0, 4.3)), // ver naar het oosten
        member('Hedwig', center), // in beeld
      ],
      onTap: (m) => tapped = m,
    );

    final avatars = tester.widgetList<MemberAvatar>(find.byType(MemberAvatar)).map((a) => a.member.userId);
    expect(avatars, unorderedEquals(['ik', 'Liam']));

    // Liam rechts aan de rand, boven het paneel.
    final screen = tester.getRect(find.byType(FlutterMap));
    final liam = arrowOf(tester, 'Liam');
    expect(liam.center.dx, greaterThan(screen.right - OffscreenMembersLayer.circle * 1.5));
    expect(liam.bottom, lessThan(screen.bottom - 200));

    await tester.tap(find.byWidgetPredicate((widget) => widget is MemberAvatar && widget.member.userId == 'Liam'));
    expect(tapped?.member.userId, 'Liam');
    expect(tester.takeException(), isNull);
  });

  testWidgets('een pijl rechts blijft weg van de knoppen', (tester) async {
    await pump(tester, [member('Liam', const LatLng(51.0, 4.3))]);
    final screen = tester.getRect(find.byType(FlutterMap));
    final buttons = Rect.fromLTRB(screen.right - 64, screen.bottom - 444, screen.right, screen.bottom - 216);
    expect(arrowOf(tester, 'Liam').overlaps(buttons), isFalse);
  });

  testWidgets('zakt het paneel, dan zakt de pijl van wie erachter stond mee of verdwijnt', (tester) async {
    final sheet = ValueNotifier<double>(200);
    addTearDown(sheet.dispose);
    // Iets onder het midden: achter het paneel zolang dat 200 hoog is.
    await pump(tester, [member('Liam', const LatLng(50.995, 4.0))], sheet: sheet);
    final screen = tester.getRect(find.byType(FlutterMap));
    expect(arrowOf(tester, 'Liam').bottom, lessThan(screen.bottom - 200));

    sheet.value = 40;
    await tester.pumpAndSettle();
    expect(find.byType(MemberAvatar), findsNothing, reason: 'nu in beeld: geen pijl meer');
  });
}
