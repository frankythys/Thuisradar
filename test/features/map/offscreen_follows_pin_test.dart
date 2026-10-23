import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:mocktail/mocktail.dart';
import 'package:thuisradar/core/theme/app_theme.dart';
import 'package:thuisradar/features/family/domain/family_member.dart';
import 'package:thuisradar/features/location/domain/member_location.dart';
import 'package:thuisradar/features/map/domain/map_view.dart';
import 'package:thuisradar/features/map/domain/member_on_map.dart';
import 'package:thuisradar/features/map/presentation/widgets/family_map.dart';
import 'package:thuisradar/features/map/presentation/widgets/google_map_stack.dart';
import 'package:thuisradar/features/map/presentation/widgets/offscreen_members_layer.dart';
import 'package:thuisradar/shared/widgets/member_avatar.dart';

class _Context extends Mock implements BuildContext {}

/// Het randblokje volgt de pin zoals je hem op de kaart ziet, niet het
/// laatst ontvangen punt.
void main() {
  const center = LatLng(51, 4);
  const zoom = 16.0;
  final start = DateTime(2026, 10, 23, 12);
  // Zelfde camera als de kaart in de test (800 × 600, niet gedraaid).
  final camera = MapCamera(
    crs: const Epsg3857(),
    center: center,
    zoom: zoom,
    rotation: 0,
    nonRotatedSize: const Size(800, 600),
  );

  MemberOnMap liam(LatLng at, {required int second, double speedMps = 15}) => MemberOnMap(
    member: const FamilyMember(userId: 'liam', displayName: 'Liam', isOwner: false, colorIndex: 1),
    location: MemberLocation(
      userId: 'liam',
      familyId: 'f',
      latitude: at.latitude,
      longitude: at.longitude,
      updatedAt: start.add(Duration(seconds: second)),
      speedMps: speedMps,
    ),
  );

  Future<void> show(WidgetTester tester, MapController controller, MemberOnMap member, int second) async {
    final stack = FamilyMap(
      controller: controller,
      useGoogleMaps: true,
      members: [member],
      now: start.add(Duration(seconds: second)),
      onMemberTap: (_) {},
      onGroupTap: (_) {},
      savedView: MapView(latitude: center.latitude, longitude: center.longitude, zoom: zoom),
    ).build(_Context()) as GoogleMapStack;
    await tester.pumpWidget(MaterialApp(theme: AppTheme.light(), home: stack.overlay((_) {})));
    await tester.pump();
  }

  bool hasBlock(WidgetTester tester) => tester.any(
    find.descendant(of: find.byType(OffscreenMembersLayer), matching: find.byType(MemberAvatar)),
  );

  testWidgets('vertrekken: geen blokje zolang de pin nog naar de rand rijdt', (tester) async {
    final controller = MapController();
    addTearDown(controller.dispose);
    await show(tester, controller, liam(center, second: 0), 0);
    expect(hasBlock(tester), isFalse);

    // Volgend punt ver buiten beeld; de pin schuift er in 5 s naartoe.
    await show(tester, controller, liam(const LatLng(51, 4.02), second: 5), 5);
    await tester.pump(const Duration(milliseconds: 300));
    expect(hasBlock(tester), isFalse, reason: 'de pin staat nog in beeld');

    await tester.pump(const Duration(seconds: 6));
    expect(hasBlock(tester), isTrue, reason: 'nu is de pin echt weg');
  });

  testWidgets('rijdend lid net onder de rand: blokje zodra de pin helemaal weg is', (tester) async {
    final controller = MapController();
    addTearDown(controller.dispose);
    // Een rijdende pin staat met zijn midden op het punt (64 breed): 20 px
    // onder de rand is hij nog half zichtbaar, 60 px eronder helemaal weg.
    await show(tester, controller, liam(camera.screenOffsetToLatLng(const Offset(400, 620)), second: 0), 0);
    expect(hasBlock(tester), isFalse, reason: 'pin nog half in beeld');

    await show(tester, controller, liam(camera.screenOffsetToLatLng(const Offset(400, 660)), second: 0), 0);
    await tester.pump(const Duration(seconds: 2));
    expect(hasBlock(tester), isTrue, reason: 'pin weg, dus een blokje');
  });
}
