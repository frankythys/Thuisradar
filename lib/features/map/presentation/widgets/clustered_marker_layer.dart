import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import '../../domain/marker_cluster.dart';
import '../../domain/member_on_map.dart';
import 'group_pin.dart';
import 'member_marker.dart';

/// Marker-laag die bij elke zoom/verschuiving herberekent welke leden samen
/// vallen (op schermafstand) en ze als losse marker of groepspin toont.
class ClusteredMarkerLayer extends StatelessWidget {
  const ClusteredMarkerLayer({
    super.key,
    required this.members,
    required this.now,
    required this.onMemberTap,
    required this.onGroupTap,
    this.selectedUserId,
    this.myUserId,
  });

  final List<MemberOnMap> members;
  final DateTime now;
  final ValueChanged<MemberOnMap> onMemberTap;
  final ValueChanged<LatLng> onGroupTap;
  final String? selectedUserId;
  final String? myUserId;

  @override
  Widget build(BuildContext context) {
    final camera = MapCamera.of(context);

    // Leden met locatie; "ik" eerst zodat ik in een groep altijd zichtbaar ben.
    final located =
        [
          for (final m in members)
            if (m.location != null) m,
        ]..sort((a, b) {
          if (a.member.userId == myUserId) return -1;
          if (b.member.userId == myUserId) return 1;
          return 0;
        });

    final byId = {for (final m in located) m.member.userId: m};
    final points = [
      for (final m in located)
        ClusterPoint(
          m.member.userId,
          camera.latLngToScreenOffset(LatLng(m.location!.latitude, m.location!.longitude)),
        ),
    ];

    final groups = clusterByScreenDistance(points);
    // Groep met de selectie als laatste tekenen (bovenop).
    groups.sort((a, b) {
      final aSel = selectedUserId != null && a.contains(selectedUserId);
      final bSel = selectedUserId != null && b.contains(selectedUserId);
      return (aSel ? 1 : 0) - (bSel ? 1 : 0);
    });

    final markers = <Marker>[];
    for (final group in groups) {
      final groupMembers = [for (final id in group) byId[id]!];
      final anchor = groupMembers.first.location!;
      final point = LatLng(anchor.latitude, anchor.longitude);

      if (groupMembers.length == 1) {
        final member = groupMembers.single;
        markers.add(
          Marker(
            point: point,
            width: MemberMarker.width,
            height: MemberMarker.height,
            alignment: Alignment.topCenter,
            child: GestureDetector(
              onTap: () => onMemberTap(member),
              child: MemberMarker(entry: member, selected: member.member.userId == selectedUserId),
            ),
          ),
        );
      } else {
        markers.add(
          Marker(
            point: point,
            width: GroupPin.width,
            height: GroupPin.height,
            alignment: Alignment.bottomCenter,
            child: GestureDetector(
              onTap: () => onGroupTap(point),
              child: GroupPin(
                members: groupMembers,
                now: now,
                myUserId: myUserId,
                selectedUserId: selectedUserId,
              ),
            ),
          ),
        );
      }
    }

    return MarkerLayer(markers: markers);
  }
}
