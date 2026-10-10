import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import '../../../../core/config/feature_flags.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../shared/widgets/app_map_tiles.dart';
import '../../../places/domain/place.dart';
import '../../../places/domain/place_status.dart';
import '../../../places/presentation/place_icons.dart';
import '../../domain/map_focus.dart';
import '../../domain/member_on_map.dart';
import 'clustered_marker_layer.dart';
import 'google_base_map.dart';

/// Kaart met een marker (of groepspin) per gezinslid met locatie. Ondergrond:
/// OpenStreetMap, of Google Maps als [useGoogleMaps] aanstaat.
class FamilyMap extends StatelessWidget {
  const FamilyMap({
    super.key,
    required this.controller,
    required this.members,
    required this.now,
    required this.onMemberTap,
    required this.onGroupTap,
    this.places = const [],
    this.placeByUser = const {},
    this.stationarySinceByUser = const {},
    this.selectedUserId,
    this.myUserId,
    this.onMapReady,
    this.onUserGesture,
    this.onMapTap,
    this.onHistory,
    this.useGoogleMaps = FeatureFlags.useGoogleMaps,
    this.satellite = false,
    this.bottomInset = 0,
  });

  static const fallbackCenter = LatLng(50.85, 4.35); // België
  static const userAgent = 'be.thuisradar.thuisradar';

  /// OpenStreetMap-tegels stoppen bij 18; Google gaat tot op straatniveau.
  static double maxZoomFor({required bool google}) => google ? 21 : 18;

  final MapController controller;
  final List<MemberOnMap> members;
  final List<Place> places;
  final Map<String, PlaceStatus> placeByUser;
  final Map<String, DateTime> stationarySinceByUser;
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
  final ValueChanged<MemberOnMap>? onHistory;

  /// Google Maps als ondergrond; de markers en gebaren blijven van flutter_map.
  final bool useGoogleMaps;

  /// Satellietbeeld (enkel met Google Maps).
  final bool satellite;

  /// Hoogte van het onderpaneel, zodat het Google-logo zichtbaar blijft.
  final double bottomInset;

  @override
  Widget build(BuildContext context) {
    final ownLocation = members.where((entry) => entry.member.userId == myUserId).firstOrNull?.location;
    final center = ownLocation == null ? fallbackCenter : LatLng(ownLocation.latitude, ownLocation.longitude);
    final zoom = ownLocation == null ? 8.0 : 12.0;
    final map = FlutterMap(
      mapController: controller,
      options: MapOptions(
        initialCenter: center,
        initialZoom: zoom,
        // Met Google Maps eronder: doorzichtig, zodat die ondergrond zichtbaar is.
        backgroundColor: useGoogleMaps ? Colors.transparent : const MapOptions().backgroundColor,
        minZoom: 3,
        maxZoom: maxZoomFor(google: useGoogleMaps),
        // Horizontaal doorlopen; alleen de boven- en onderrand begrenzen.
        cameraConstraint: const CameraConstraint.containLatitude(),
        onMapReady: onMapReady,
        onTap: (_, _) => onMapTap?.call(),
        onPositionChanged: (camera, hasGesture) {
          if (hasGesture) onUserGesture?.call();
        },
        interactionOptions: const InteractionOptions(flags: InteractiveFlag.all & ~InteractiveFlag.rotate),
      ),
      children: [
        if (!useGoogleMaps) const AppMapTiles(),
        // Met Google Maps tekent Google de plaatsen zelf (zie GoogleBaseMap).
        if (places.isNotEmpty && !useGoogleMaps) ...[
          CircleLayer(
            circles: [
              for (final place in places)
                CircleMarker(
                  point: LatLng(place.latitude, place.longitude),
                  radius: place.radiusMeters.toDouble(),
                  useRadiusInMeter: true,
                  color: AppColors.primary.withValues(alpha: 0.08),
                  borderColor: AppColors.primary.withValues(alpha: 0.5),
                  borderStrokeWidth: 1.5,
                ),
            ],
          ),
          MarkerLayer(
            markers: [
              for (final place in places)
                Marker(
                  point: LatLng(place.latitude, place.longitude),
                  width: 32,
                  height: 32,
                  child: Icon(placeIcon(place.icon), size: 20, color: AppColors.primary),
                ),
            ],
          ),
        ],
        ClusteredMarkerLayer(
          reservedPlaces: [
            for (final place in places)
              if (place.icon == 'home') LatLng(place.latitude, place.longitude),
          ],
          members: membersToShow(members, selectedUserId),
          now: now,
          placeByUser: placeByUser,
          stationarySinceByUser: stationarySinceByUser,
          onMemberTap: onMemberTap,
          onHistory: onHistory,
          onGroupTap: onGroupTap,
          selectedUserId: selectedUserId,
          myUserId: myUserId,
        ),
        if (!useGoogleMaps) const SimpleAttributionWidget(source: Text('OpenStreetMap-bijdragers')),
      ],
    );
    if (!useGoogleMaps) return map;
    return Stack(
      children: [
        Positioned.fill(
          child: GoogleBaseMap(
            controller: controller,
            initialCenter: center,
            initialZoom: zoom,
            satellite: satellite,
            bottomPadding: bottomInset,
            places: places,
          ),
        ),
        map,
      ],
    );
  }
}
