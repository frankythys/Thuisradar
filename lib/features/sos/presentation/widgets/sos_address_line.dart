import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_tokens.dart';
import '../../../../core/utils/time_format.dart';
import '../../../location/application/address_providers.dart';
import '../../../location/domain/place_address.dart';
import '../../../places/application/places_providers.dart';
import '../../../places/domain/place_timeline.dart';

/// Waar het alarm vandaan komt: een eigen plaats of het adres (gratis reverse
/// geocoding van het toestel), nooit kale coördinaten.
class SosAddressLine extends ConsumerWidget {
  const SosAddressLine({
    super.key,
    required this.familyId,
    required this.latitude,
    required this.longitude,
    required this.sharedAt,
    required this.now,
  });

  final String familyId;
  final double latitude;
  final double longitude;
  final DateTime sharedAt;
  final DateTime now;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final text = Theme.of(context).textTheme;
    final tokens = context.tokens;
    final places = ref.watch(familyPlacesProvider(familyId)).value ?? const [];
    final address = ref.watch(placeAddressProvider(snapToAddressGrid(latitude, longitude)));
    final place = placeNameAt(places, latitude, longitude);
    final street = address.value?.label ?? '';

    final title =
        place ??
        (street.isNotEmpty
            ? street
            : address.isLoading
            ? 'Adres opzoeken…'
            : 'Adres onbekend');
    final subtitle = [
      if (place != null && street.isNotEmpty) street,
      'Gedeeld ${formatRelative(sharedAt, now: now)}',
    ].join(' · ');

    return Row(
      children: [
        Container(
          width: 40,
          height: 40,
          decoration: const BoxDecoration(color: AppColors.primarySoft, shape: BoxShape.circle),
          child: const Icon(Icons.place_outlined, color: AppColors.primary, size: 22),
        ),
        SizedBox(width: tokens.spaceSm + tokens.spaceXs),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: text.titleMedium, maxLines: 1, overflow: TextOverflow.ellipsis),
              Text(
                subtitle,
                style: text.bodySmall?.copyWith(color: AppColors.muted),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ],
    );
  }
}
