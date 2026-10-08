import 'package:thuisradar/core/theme/app_theme.dart';
import 'package:thuisradar/shared/widgets/member_avatar.dart';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:thuisradar/features/family/domain/family_member.dart';
import 'package:thuisradar/features/location/domain/member_location.dart';
import 'package:thuisradar/features/map/domain/member_on_map.dart';
import 'package:thuisradar/features/map/presentation/widgets/clustered_marker_layer.dart';
import 'package:thuisradar/features/map/presentation/widgets/member_history_bubble.dart';
import 'package:thuisradar/features/places/domain/place_status.dart';

void main() {
  final now = DateTime(2026, 10, 4, 12);
  MemberOnMap member(String id) => MemberOnMap(
    member: FamilyMember(
      userId: id,
      displayName: id,
      isOwner: false,
      colorIndex: 0,
    ),
    location: MemberLocation(
      userId: id,
      familyId: 'fam',
      latitude: 51,
      longitude: 3,
      updatedAt: now,
      speedMps: 0,
    ),
  );

  MemberOnMap movingMember(String id) => MemberOnMap(
    member: FamilyMember(
      userId: id,
      displayName: id,
      isOwner: false,
      colorIndex: 0,
    ),
    location: MemberLocation(
      userId: id,
      familyId: 'fam',
      latitude: 51,
      longitude: 3,
      updatedAt: now,
      speedMps: 12.5,
    ),
  );

  testWidgets(
    'geselecteerd groepslid heeft een aanklikbare geschiedenisballon',
    (tester) async {
      String? opened;
      final controller = MapController();
      addTearDown(controller.dispose);
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light(),
          home: Scaffold(
            body: FlutterMap(
              mapController: controller,
              options: const MapOptions(
                initialCenter: LatLng(51, 3),
                initialZoom: 16,
              ),
              children: [
                ClusteredMarkerLayer(
                  members: [member('Liam'), member('Franky')],
                  now: now,
                  selectedUserId: 'Franky',
                  onMemberTap: (_) {},
                  onGroupTap: (_) {},
                  onHistory: (entry) => opened = entry.member.userId,
                  placeByUser: {
                    'Franky': PlaceStatus(
                      name: 'Thuis',
                      icon: 'home',
                      since: now.subtract(
                        const Duration(hours: 2, minutes: 15),
                      ),
                    ),
                  },
                ),
              ],
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Thuis'), findsOneWidget);
      expect(
        find.byWidgetPredicate(
          (widget) =>
              widget is Image &&
              widget.image is AssetImage &&
              (widget.image as AssetImage).assetName ==
                  'assets/markers/huis.png',
        ),
        findsOneWidget,
      );
      expect(find.text('sinds 2 uur, 15 min'), findsOneWidget);
      final avatar = find.byWidgetPredicate(
        (widget) => widget is MemberAvatar && widget.member.userId == 'Franky',
      );
      Offset checkPosition() {
        final avatarRect = tester.getRect(avatar);
        final bubbleRect = tester.getRect(find.byType(MemberHistoryBubble));
        expect(bubbleRect.top, lessThan(avatarRect.top));
        // De ballon overlapt de bovenrand van de avatar, zoals de referentie.
        expect(
          bubbleRect.left,
          inInclusiveRange(avatarRect.left, avatarRect.right),
        );
        expect(bubbleRect.bottom, greaterThan(avatarRect.top));
        return bubbleRect.topLeft - avatarRect.topLeft;
      }

      final offset = checkPosition();
      for (final center in [const LatLng(51, 3.001), const LatLng(51, 2.999)]) {
        controller.move(center, 17);
        await tester.pumpAndSettle();
        final movedOffset = checkPosition();
        expect(movedOffset.dx, closeTo(offset.dx, 0.01));
        expect(movedOffset.dy, closeTo(offset.dy, 0.01));
      }
      await tester.tap(find.text('sinds 2 uur, 15 min'));
      expect(opened, 'Franky');
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('zonder verblijfstijd wordt geen duur verzonnen', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        home: Scaffold(
          body: Center(
            child: SizedBox(
              width: 142,
              height: 48,
              child: MemberHistoryBubble(
                entry: member('Liam'),
                now: now,
                onTap: () {},
              ),
            ),
          ),
        ),
      ),
    );
    expect(find.textContaining('sinds'), findsNothing);
    expect(find.textContaining('bijgewerkt'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('stilstaand buiten een plek toont hoelang je hier bent', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        home: Scaffold(
          body: Center(
            child: SizedBox(
              width: 142,
              height: 48,
              child: MemberHistoryBubble(
                entry: member('Liam'),
                now: now,
                onTap: () {},
                stationarySince: now.subtract(const Duration(minutes: 3)),
              ),
            ),
          ),
        ),
      ),
    );
    expect(find.text('Stilstaand'), findsOneWidget);
    expect(find.text('sinds 3 min'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('rijdend lid toont auto en snelheid in de geschiedenisballon', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        home: Scaffold(
          body: Center(
            child: SizedBox(
              width: 142,
              height: 48,
              child: MemberHistoryBubble(
                entry: movingMember('Liam'),
                now: now,
                onTap: () {},
                placeStatus: PlaceStatus(
                  name: 'Thuis',
                  icon: 'home',
                  since: now.subtract(const Duration(minutes: 15)),
                ),
              ),
            ),
          ),
        ),
      ),
    );
    expect(find.byIcon(Icons.directions_car), findsOneWidget);
    expect(find.text('Onderweg'), findsOneWidget);
    expect(find.text('45 km/u'), findsOneWidget);
    expect(find.text('Hier sinds'), findsNothing);
    expect(tester.takeException(), isNull);
  });
}
