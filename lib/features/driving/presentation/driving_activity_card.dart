import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:latlong2/latlong.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_tokens.dart';
import '../../../shared/widgets/app_card.dart';
import '../../../shared/widgets/location_preview.dart';
import '../../location/application/address_providers.dart';
import '../../location/domain/place_address.dart';
import '../../location/domain/track_point.dart';
import '../../location/domain/track_segments.dart';
import '../../places/domain/place.dart';
import '../../places/domain/place_timeline.dart';
import '../domain/driving_activity.dart';
import 'driving_summary.dart';

/// Eén activiteit als kaart: een rit (met de route op een kaart, van → naar,
/// tijd en afstand) of een verblijf (plek, tijd en duur).
class DrivingActivityCard extends StatelessWidget {
  const DrivingActivityCard({
    super.key,
    required this.activity,
    required this.places,
    this.route = const [],
    this.onSaveAsPlace,
  });

  final DrivingActivity activity;
  final List<Place> places;

  /// Verblijf op een plek die nog geen eigen plaats is: knop "Plaats opslaan".
  final VoidCallback? onSaveAsPlace;

  /// De GPS-punten van deze rit; die tekenen de kaart boven de ritgegevens.
  final List<TrackPoint> route;

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    // Gaten in de metingen worden niet verbonden: elk aaneengesloten stuk is
    // een eigen lijn, zodat er nooit een rechte lijn door de stad loopt.
    final segments = [
      for (final segment in routeMapSegments(route))
        [for (final point in segment) LatLng(point.latitude, point.longitude)],
    ];
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (activity.kind == DrivingActivityKind.trip &&
              segments.isNotEmpty) ...[
            LocationPreview(
              latitude: route.last.latitude,
              longitude: route.last.longitude,
              height: 170,
              allowFullscreen: true,
              fitBounds: true,
              showMarker: false,
              segments: segments,
            ),
            SizedBox(height: tokens.spaceMd),
          ],
          switch (activity.kind) {
            DrivingActivityKind.trip => _TripBody(
              activity: activity,
              places: places,
              topSpeed: topSpeedKmh(route),
            ),
            DrivingActivityKind.stay => _StayBody(
              activity: activity,
              places: places,
              onSaveAsPlace:
                  placeNameAt(places, activity.latitude, activity.longitude) ==
                      null
                  ? onSaveAsPlace
                  : null,
            ),
          },
        ],
      ),
    );
  }
}

class _TripBody extends StatelessWidget {
  const _TripBody({
    required this.activity,
    required this.places,
    this.topSpeed,
  });

  final DrivingActivity activity;
  final List<Place> places;

  /// Hoogste gemeten snelheid in km/u, indien bekend.
  final int? topSpeed;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final tokens = context.tokens;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Wrap(
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  _PlaceLabel(
                    places: places,
                    latitude: activity.fromLatitude,
                    longitude: activity.fromLongitude,
                  ),
                  const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 6),
                    child: Icon(
                      Icons.arrow_forward,
                      size: 16,
                      color: AppColors.muted,
                    ),
                  ),
                  _PlaceLabel(
                    places: places,
                    latitude: activity.latitude,
                    longitude: activity.longitude,
                  ),
                ],
              ),
            ),
            SizedBox(width: tokens.spaceSm),
            const Icon(Icons.directions_car_outlined, color: AppColors.primary),
          ],
        ),
        SizedBox(height: tokens.spaceSm),
        Text(
          '${drivingTime(activity.start)} - ${drivingTime(activity.end)}'
          ' · ${drivingDistance(activity.distanceMeters)}',
          style: text.bodyMedium?.copyWith(color: AppColors.muted),
        ),
        if (topSpeed case final speed?) ...[
          SizedBox(height: tokens.spaceXs),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.speed, size: 16, color: AppColors.muted),
              const SizedBox(width: 6),
              Text('max $speed km/u', style: text.labelLarge),
            ],
          ),
        ],
      ],
    );
  }
}

class _StayBody extends StatelessWidget {
  const _StayBody({
    required this.activity,
    required this.places,
    this.onSaveAsPlace,
  });

  final DrivingActivity activity;
  final List<Place> places;
  final VoidCallback? onSaveAsPlace;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final tokens = context.tokens;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: _PlaceLabel(
                places: places,
                latitude: activity.latitude,
                longitude: activity.longitude,
                fallback: 'Op één plek',
              ),
            ),
            SizedBox(width: tokens.spaceSm),
            const Icon(Icons.location_on, color: AppColors.primary),
          ],
        ),
        SizedBox(height: tokens.spaceSm),
        Text(
          '${drivingTime(activity.start)} - ${drivingTime(activity.end)}',
          style: text.bodyMedium?.copyWith(color: AppColors.muted),
        ),
        SizedBox(height: tokens.spaceXs),
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.schedule, size: 16, color: AppColors.muted),
            const SizedBox(width: 6),
            Text(drivingDuration(activity.duration), style: text.labelLarge),
            if (onSaveAsPlace case final save?) ...[
              SizedBox(width: tokens.spaceMd),
              TextButton.icon(
                onPressed: save,
                icon: const Icon(Icons.add_location_alt_outlined, size: 18),
                label: const Text('Plaats opslaan'),
              ),
            ],
          ],
        ),
      ],
    );
  }
}

/// Naam van een plek: eerst een eigen plaats, anders het adres van het toestel
/// (gratis reverse geocoding). Toont [fallback] als er niets bekend is.
class _PlaceLabel extends ConsumerWidget {
  const _PlaceLabel({
    required this.places,
    required this.latitude,
    required this.longitude,
    this.fallback = 'Onbekend',
  });

  final List<Place> places;
  final double? latitude;
  final double? longitude;
  final String fallback;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final lat = latitude;
    final lng = longitude;
    final style = Theme.of(context).textTheme.titleMedium;
    if (lat == null || lng == null) return Text(fallback, style: style);

    final known = placeNameAt(places, lat, lng);
    if (known != null) return Text(known, style: style);

    final address = ref
        .watch(placeAddressProvider(snapToAddressGrid(lat, lng)))
        .value;
    final label = address == null || address.isEmpty ? fallback : address.label;
    return Text(label, style: style);
  }
}
