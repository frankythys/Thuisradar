import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import '../../../core/config/feature_flags.dart';
import '../../../core/theme/app_colors.dart';
import '../../../shared/widgets/app_map_tiles.dart';
import '../../map/presentation/widgets/google_base_map.dart';
import '../../../l10n/l10n.dart';

/// De kaart van het plaatsscherm (toevoegen of bewerken, bv. "Werk"): je
/// verschuift de kaart onder het vaste kruis. Zelfde ondergrond als de
/// hoofdkaart: Google Maps als [useGoogleMaps] aanstaat, anders OpenStreetMap.
class PlaceEditMap extends StatelessWidget {
  const PlaceEditMap({
    super.key,
    required this.controller,
    required this.center,
    required this.radiusMeters,
    required this.onPositionChanged,
    this.useGoogleMaps = FeatureFlags.useGoogleMaps,
  });

  final MapController controller;
  final LatLng center;
  final double radiusMeters;
  final void Function(MapCamera camera, bool hasGesture) onPositionChanged;
  final bool useGoogleMaps;

  /// Hoe dicht je kan inzoomen om nauwkeurig te plaatsen: OpenStreetMap stopt
  /// bij 19, Google gaat tot straatniveau.
  static double maxZoomFor({required bool google}) => google ? 21 : 19;

  @override
  Widget build(BuildContext context) {
    final map = FlutterMap(
      mapController: controller,
      options: MapOptions(
        initialCenter: center,
        initialZoom: 16,
        minZoom: 3,
        maxZoom: maxZoomFor(google: useGoogleMaps),
        // Met Google eronder: doorzichtig, zodat die ondergrond zichtbaar is.
        backgroundColor: useGoogleMaps ? Colors.transparent : const MapOptions().backgroundColor,
        cameraConstraint: CameraConstraint.contain(
          bounds: LatLngBounds(const LatLng(-85, -180), const LatLng(85, 180)),
        ),
        onPositionChanged: onPositionChanged,
        interactionOptions: const InteractionOptions(flags: InteractiveFlag.all & ~InteractiveFlag.rotate),
      ),
      children: [
        if (!useGoogleMaps) const AppMapTiles(),
        // De straal staat altijd rond het midden (onder het kruis), dus ze
        // glijdt niet mee als Google even achterloopt.
        CircleLayer(
          circles: [
            CircleMarker(
              point: center,
              radius: radiusMeters,
              useRadiusInMeter: true,
              color: AppColors.primary.withValues(alpha: 0.12),
              borderColor: AppColors.primary,
              borderStrokeWidth: 2,
            ),
          ],
        ),
        // Verplichte naamsvermelding van de gratis OpenStreetMap-tegels, klein
        // tussen de sleep-hint (links) en de locatieknop (rechts).
        if (!useGoogleMaps)
          Align(
            alignment: Alignment.bottomCenter,
            child: Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: Text(
                '© ${context.l10n.osmContributors}',
                style: const TextStyle(fontSize: 9, color: AppColors.muted),
              ),
            ),
          ),
      ],
    );
    if (!useGoogleMaps) return map;
    return Stack(
      children: [
        // Google volgt de camera van de kaart erboven; alle gebaren blijven daar.
        Positioned.fill(
          child: GoogleBaseMap(controller: controller, initialCenter: center, initialZoom: 16),
        ),
        map,
      ],
    );
  }
}
