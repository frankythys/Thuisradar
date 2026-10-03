import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import '../../domain/member_on_map.dart';
import 'clustered_marker_layer.dart';

/// OpenStreetMap-kaart met een marker (of groepspin) per gezinslid met locatie.
class FamilyMap extends StatelessWidget {
  const FamilyMap({
    super.key,
    required this.controller,
    required this.members,
    required this.now,
    required this.onMemberTap,
    required this.onGroupTap,
    this.selectedUserId,
    this.myUserId,
    this.onMapReady,
    this.onUserGesture,
    this.onMapTap,
  });

  static const fallbackCenter = LatLng(50.85, 4.35); // België
  static const userAgent = 'be.thuisradar.thuisradar';

  final MapController controller;
  final List<MemberOnMap> members;
  final DateTime now;
  final ValueChanged<MemberOnMap> onMemberTap;
  final ValueChanged<LatLng> onGroupTap;
  final String? selectedUserId;
  final String? myUserId;
  final VoidCallback? onMapReady;

  /// Vuurt wanneer de gebruiker zelf de kaart zoomt of verschuift.
  final VoidCallback? onUserGesture;

  /// Tik op een lege plek op de kaart (om de selectie op te heffen).
  final VoidCallback? onMapTap;

  @override
  Widget build(BuildContext context) {
    return FlutterMap(
      mapController: controller,
      options: MapOptions(
        initialCenter: fallbackCenter,
        initialZoom: 8,
        onMapReady: onMapReady,
        onTap: (_, _) => onMapTap?.call(),
        onPositionChanged: (camera, hasGesture) {
          if (hasGesture) onUserGesture?.call();
        },
        interactionOptions: const InteractionOptions(flags: InteractiveFlag.all & ~InteractiveFlag.rotate),
      ),
      children: [
        TileLayer(
          urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
          userAgentPackageName: userAgent,
        ),
        ClusteredMarkerLayer(
          members: members,
          now: now,
          onMemberTap: onMemberTap,
          onGroupTap: onGroupTap,
          selectedUserId: selectedUserId,
          myUserId: myUserId,
        ),
        const SimpleAttributionWidget(source: Text('OpenStreetMap-bijdragers')),
      ],
    );
  }
}
