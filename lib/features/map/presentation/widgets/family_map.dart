import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import '../../domain/member_on_map.dart';
import 'member_marker.dart';

/// OpenStreetMap-kaart met een marker per gezinslid dat een locatie heeft.
class FamilyMap extends StatelessWidget {
  const FamilyMap({super.key, required this.controller, required this.members, this.onMapReady});

  static const fallbackCenter = LatLng(50.85, 4.35); // België
  static const userAgent = 'be.thuisradar.thuisradar';

  final MapController controller;
  final List<MemberOnMap> members;
  final VoidCallback? onMapReady;

  @override
  Widget build(BuildContext context) {
    return FlutterMap(
      mapController: controller,
      options: MapOptions(
        initialCenter: fallbackCenter,
        initialZoom: 8,
        onMapReady: onMapReady,
        interactionOptions: const InteractionOptions(flags: InteractiveFlag.all & ~InteractiveFlag.rotate),
      ),
      children: [
        TileLayer(
          urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
          userAgentPackageName: userAgent,
        ),
        MarkerLayer(
          markers: [
            for (final entry in members)
              if (entry.location case final location?)
                Marker(
                  point: LatLng(location.latitude, location.longitude),
                  width: MemberMarker.width,
                  height: MemberMarker.height,
                  alignment: Alignment.topCenter,
                  child: MemberMarker(entry: entry),
                ),
          ],
        ),
        const SimpleAttributionWidget(source: Text('OpenStreetMap-bijdragers')),
      ],
    );
  }
}
