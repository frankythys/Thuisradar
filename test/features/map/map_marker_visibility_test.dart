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
import 'package:thuisradar/features/map/presentation/widgets/group_pin_backdrop.dart';
import 'package:thuisradar/features/map/presentation/widgets/member_marker.dart';
import 'package:thuisradar/shared/widgets/member_avatar.dart';

void main() {
  final now = DateTime(2026, 10, 5, 12);
  MemberOnMap member(String id) => MemberOnMap(
    member: FamilyMember(
      userId: id,
      displayName: id,
      isOwner: false,
      colorIndex: 0,
    ),
    location: MemberLocation(
      userId: id,
      familyId: 'family',
      latitude: 51,
      longitude: 3,
      updatedAt: now,
      speedMps: 0,
    ),
  );

  testWidgets('groepscirkels bedekken huis niet bij inzoomen', (tester) async {
    final controller = MapController();
    const home = LatLng(51, 3);
    const homeKey = ValueKey('home-marker');
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        home: Scaffold(
          body: FlutterMap(
            mapController: controller,
            options: const MapOptions(initialCenter: home, initialZoom: 16),
            children: [
              MarkerLayer(
                markers: [
                  Marker(
                    point: home,
                    width: 32,
                    height: 32,
                    child: const Icon(Icons.home, key: homeKey),
                  ),
                ],
              ),
              ClusteredMarkerLayer(
                members: [member('Franky'), member('Liam')],
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
    await tester.pumpAndSettle();
    for (final zoom in [16.0, 17.0, 18.0]) {
      controller.move(home, zoom);
      await tester.pumpAndSettle();
      expect(
        tester
            .getRect(find.byType(GroupPin))
            .overlaps(tester.getRect(find.byKey(homeKey))),
        isFalse,
      );
    }
    await tester.pumpWidget(const SizedBox());
    controller.dispose();
  });

  testWidgets(
    'rijdende persoonscirkel staat op wegpunt met aansluitende tekstballon',
    (tester) async {
      final controller = MapController();
      const point = LatLng(51, 3);
      const pointKey = ValueKey('exact-coordinate');
      final cars = [
        for (final id in ['Franky', 'Liam'])
          MemberOnMap(
            member: member(id).member,
            location: MemberLocation(
              userId: id,
              familyId: 'family',
              latitude: 51,
              longitude: 3,
              updatedAt: now,
              speedMps: 10,
            ),
          ),
      ];
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light(),
          home: Scaffold(
            body: FlutterMap(
              mapController: controller,
              options: const MapOptions(initialCenter: point, initialZoom: 16),
              children: [
                MarkerLayer(
                  markers: [
                    Marker(
                      point: point,
                      width: 2,
                      height: 2,
                      child: const SizedBox(key: pointKey),
                    ),
                  ],
                ),
                ClusteredMarkerLayer(
                  members: cars,
                  now: now,
                  selectedUserId: 'Franky',
                  reservedPlaces: const [point],
                  onMemberTap: (_) {},
                  onGroupTap: (_) {},
                ),
              ],
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      final oldCarImages = find.byWidgetPredicate(
        (widget) =>
            widget is Image &&
            widget.image is AssetImage &&
            (widget.image as AssetImage).assetName == 'assets/markers/auto.png',
      );
      expect(oldCarImages, findsNothing);
      final circles = find.byType(MemberAvatar);
      expect(circles, findsNWidgets(2));
      expect(find.byType(GroupPin), findsNothing);
      for (final zoom in [16.0, 18.0]) {
        controller.move(point, zoom);
        await tester.pumpAndSettle();
        for (var i = 0; i < 2; i++) {
          expect(
            (tester.getCenter(circles.at(i)) -
                    tester.getCenter(find.byKey(pointKey)))
                .distance,
            lessThan(0.1),
          );
        }
        final franky = find.byWidgetPredicate(
          (widget) =>
              widget is MemberAvatar && widget.member.userId == 'Franky',
        );
        expect(
          tester.getRect(find.text('Rijden')).top,
          lessThan(tester.getRect(franky).top),
        );
      }
      await tester.pumpWidget(const SizedBox());
      controller.dispose();
    },
  );

  testWidgets(
    'stilstaand lid houdt infolabel zonder selectie of geschiedeniscallback',
    (tester) async {
      var opened = false;
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light(),
          home: Scaffold(
            body: FlutterMap(
              options: const MapOptions(
                initialCenter: LatLng(51, 3),
                initialZoom: 16,
              ),
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
    },
  );

  testWidgets(
    'grote geselecteerde avatar gebruikt gereserveerde rand zonder wit',
    (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light(),
          home: Scaffold(
            body: Center(
              child: SizedBox(
                width: MemberMarker.width,
                height: MemberMarker.height,
                child: MemberMarker(
                  entry: member('Franky'),
                  now: now,
                  selected: true,
                ),
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
              (widget.decoration! as BoxDecoration).color ==
                  AppColors.mapSelection,
        ),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
    },
  );

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

  testWidgets('groepspin met grote avatars en extra leden past in marker', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        home: Scaffold(
          body: Center(
            child: SizedBox(
              width: GroupPin.width,
              height: GroupPin.height,
              child: GroupPin(
                members: [
                  member('Franky'),
                  member('Liam'),
                  member('Hedwig'),
                  member('F'),
                ],
                now: now,
                selectedUserId: 'Franky',
              ),
            ),
          ),
        ),
      ),
    );
    expect(find.text('+1'), findsOneWidget);
    // De gezamenlijke witte vorm houdt de grote maat (72); de gezichten zelf
    // liggen erbinnen met een dun wit scheidingslijntje of de paarse rand.
    expect(
      tester.widget<GroupPinBackdrop>(find.byType(GroupPinBackdrop)).diameter,
      72,
    );
    expect(
      tester
          .widgetList<MemberAvatar>(find.byType(MemberAvatar))
          .every((avatar) => avatar.size >= 60),
      isTrue,
    );
    expect(tester.takeException(), isNull);
  });
}
