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
import 'package:thuisradar/features/map/presentation/widgets/member_history_bubble.dart';
import 'package:thuisradar/features/map/presentation/widgets/member_marker.dart';
import 'package:thuisradar/features/map/presentation/widgets/walking_gif_frames.dart';
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
    MemberOnMap? member,
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
                members: [member ?? franky],
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

  testWidgets('met Google: wandelend krijgt de ballon een aparte, geanimeerde sneaker-marker', (
    tester,
  ) async {
    final walking = MemberOnMap(
      member: franky.member,
      location: MemberLocation(
        userId: 'Franky',
        familyId: 'gezin',
        latitude: 51,
        longitude: 3,
        updatedAt: now,
        speedMps: 1.3,
      ),
    );
    var specs = await pumpNative(tester, member: walking);
    // De GIF-beelden laden op de achtergrond; daarna komt de animatie erbij.
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 500)));
    await tester.pump(const Duration(milliseconds: 100));
    specs = await pumpNative(tester, member: walking);

    final bubble = specs.firstWhere((s) => s.id == 'bubble_Franky');
    final walker = specs.firstWhere((s) => s.id == 'walker_Franky');
    expect(bubble.frames, isEmpty);
    expect(walker.frames, hasLength(kWalkingLoopFrames));
    // Klein (enkel de sneakers), exact op de lege plek in de ballon, en erna
    // getekend (bovenop).
    Rect box(MapMarkerSpec spec) => Rect.fromCenter(
      center: Offset(
        spec.alignment.x * spec.width / 2 + spec.offset.dx,
        spec.alignment.y * spec.height / 2 + spec.offset.dy,
      ),
      width: spec.width,
      height: spec.height,
    );
    expect(walker.point, bubble.point);
    expect(walker.width, MemberHistoryBubble.walkerSlot.width);
    expect(walker.margin, lessThan(24));
    final expected = MemberHistoryBubble.walkerSlot.shift(box(bubble).topLeft);
    expect(box(walker).left, closeTo(expected.left, 1e-9));
    expect(box(walker).top, closeTo(expected.top, 1e-9));
    expect(specs.indexOf(walker), greaterThan(specs.indexOf(bubble)));
    // Tikken gaat via de ballon zelf.
    expect(walker.onTap, isNull);
  });
}
