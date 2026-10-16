import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../places/domain/place.dart';
import '../../domain/place_radius.dart';

/// Straal (perimeter) van de plaatsen op de OpenStreetMap-kaart. Pas zichtbaar
/// als je ver ingezoomd bent; uitgezoomd blijft enkel het icoon.
class PlaceRadiusLayer extends StatelessWidget {
  const PlaceRadiusLayer({super.key, required this.places});

  final List<Place> places;

  @override
  Widget build(BuildContext context) {
    if (!showsPlaceRadius(MapCamera.of(context).zoom)) return const SizedBox.shrink();
    return CircleLayer(
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
    );
  }
}
