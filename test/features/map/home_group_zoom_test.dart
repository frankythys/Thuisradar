import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:thuisradar/core/theme/app_theme.dart';
import 'package:thuisradar/features/family/domain/family_member.dart';
import 'package:thuisradar/features/location/domain/member_location.dart';
import 'package:thuisradar/features/map/domain/marker_cluster.dart';
import 'package:thuisradar/features/map/domain/member_on_map.dart';
import 'package:thuisradar/features/map/presentation/widgets/clustered_marker_layer.dart';
import 'package:thuisradar/features/map/presentation/widgets/group_pin.dart';
import 'package:thuisradar/features/map/presentation/widgets/member_marker.dart';

const _home = LatLng(51.0, 4.0);

/// Zoals de app thuis doet: elk lid 18 m van het midden, in een waaiertje.
LatLng _fanned(int index, int total) {
  final angle = 2 * math.pi * index / total;
  return LatLng(
    _home.latitude + 18 * math.sin(angle) / 111320,
    _home.longitude + 18 * math.cos(angle) / (111320 * math.cos(_home.latitude * math.pi / 180)),
  );
}

/// Schermpositie (punten) in Web Mercator op een zoomniveau.
Offset _screen(LatLng p, double zoom) {
  final size = 256 * math.pow(2, zoom);
  final s = math.sin(p.latitude * math.pi / 180);
  return Offset((p.longitude + 180) / 360 * size, (0.5 - math.log((1 + s) / (1 - s)) / (4 * math.pi)) * size);
}

void main() {
  final names = ['Franky', 'Liam', 'Mama'];
  final positions = [for (var i = 0; i < 3; i++) _fanned(i, 3)];

  List<List<String>> groupsAt(double zoom, {List<LatLng>? at}) => clusterByMetersAndScreen([
    for (var i = 0; i < 3; i++)
      GeoScreenClusterPoint(
        names[i],
        (at ?? positions)[i].latitude,
        (at ?? positions)[i].longitude,
        _screen((at ?? positions)[i], zoom),
      ),
  ]);

  test('allemaal thuis, uitgezoomd: één groepspin', () {
    expect(groupsAt(15), [names]);
  });

  test('allemaal thuis, ingezoomd op Thuis: elk apart', () {
    expect(groupsAt(19), [
      ['Franky'],
      ['Liam'],
      ['Mama'],
    ]);
  });

  test('Liam op school (1 km verder) blijft apart, ook uitgezoomd', () {
    final elsewhere = [positions[0], const LatLng(51.009, 4.0), positions[2]];
    final groups = groupsAt(10, at: elsewhere);
    expect(groups, hasLength(2));
    expect(groups.firstWhere((g) => g.contains('Liam')), ['Liam']);
  });

  testWidgets('op de kaart: inzoomen op Thuis splitst de groepspin in drie rondjes', (tester) async {
    final now = DateTime(2026, 10, 10, 18);
    final controller = MapController();
    final members = [
      for (var i = 0; i < 3; i++)
        MemberOnMap(
          member: FamilyMember(userId: names[i], displayName: names[i], isOwner: i == 0, colorIndex: i),
          location: MemberLocation(
            userId: names[i],
            familyId: 'gezin',
            latitude: positions[i].latitude,
            longitude: positions[i].longitude,
            updatedAt: now,
            speedMps: 0,
          ),
        ),
    ];
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        home: Scaffold(
          body: FlutterMap(
            mapController: controller,
            options: const MapOptions(initialCenter: _home, initialZoom: 15, maxZoom: 21),
            children: [
              ClusteredMarkerLayer(members: members, now: now, onMemberTap: (_) {}, onGroupTap: (_) {}),
            ],
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.byType(GroupPin), findsOneWidget);
    expect(find.byType(MemberMarker), findsNothing);

    controller.move(_home, 19);
    await tester.pumpAndSettle();
    expect(find.byType(GroupPin), findsNothing);
    expect(find.byType(MemberMarker), findsNWidgets(3));
  });
}
