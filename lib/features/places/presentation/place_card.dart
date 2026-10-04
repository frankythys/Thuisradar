import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../shared/widgets/app_card.dart';
import '../domain/place.dart';
import 'place_icons.dart';

class PlaceCard extends StatelessWidget {
  const PlaceCard({
    super.key,
    required this.place,
    required this.presentCount,
    required this.onDelete,
  });
  final Place place;
  final int presentCount;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final tint = place.icon == 'school'
        ? AppColors.secondary
        : place.icon == 'sports'
        ? AppColors.alert
        : AppColors.primary;
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: tint.withValues(alpha: .1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(placeIcon(place.icon), color: tint),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(place.name, style: text.titleLarge),
                    const SizedBox(height: 3),
                    Text(
                      place.address ??
                          '${place.latitude.toStringAsFixed(4)}, ${place.longitude.toStringAsFixed(4)}',
                      style: text.bodySmall?.copyWith(color: AppColors.muted),
                    ),
                  ],
                ),
              ),
              IconButton(
                onPressed: onDelete,
                tooltip: 'Verwijderen',
                icon: const Icon(Icons.delete_outline, size: 20),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 12,
            runSpacing: 4,
            children: [
              _Label(Icons.adjust, 'Straal ${place.radiusMeters} m'),
              _Label(
                Icons.people_outline,
                place.watchedMembers?.isNotEmpty == true
                    ? 'Voor: ${place.watchedMembers!.length} leden'
                    : 'Voor: Iedereen',
              ),
            ],
          ),
          const SizedBox(height: 14),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppColors.surfaceLow,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                Icon(
                  presentCount == 0
                      ? Icons.bedtime_outlined
                      : Icons.person_pin_circle_outlined,
                  size: 18,
                  color: tint,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    presentCount == 0
                        ? 'Niemand aanwezig'
                        : '$presentCount ${presentCount == 1 ? 'gezinslid' : 'gezinsleden'} hier',
                    style: text.labelMedium,
                  ),
                ),
                Text(
                  presentCount == 0 ? 'Inactief' : 'Aanwezig',
                  style: text.bodySmall?.copyWith(color: AppColors.primary),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              Text(
                'MELDINGEN',
                style: text.labelSmall?.copyWith(
                  fontSize: 9,
                  color: AppColors.muted,
                ),
              ),
              _Preference('Aankomst', place.notifyArrival),
              _Preference('Vertrek', place.notifyDeparture),
            ],
          ),
        ],
      ),
    );
  }
}

class _Label extends StatelessWidget {
  const _Label(this.icon, this.label);
  final IconData icon;
  final String label;
  @override
  Widget build(BuildContext context) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      Icon(icon, size: 13, color: AppColors.muted),
      const SizedBox(width: 4),
      Text(
        label,
        style: Theme.of(context).textTheme.bodySmall
            ?.copyWith(color: AppColors.muted),
      ),
    ],
  );
}

class _Preference extends StatelessWidget {
  const _Preference(this.label, this.enabled);
  final String label;
  final bool enabled;
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
    decoration: BoxDecoration(
      color: enabled ? const Color(0xFFB8ECDD) : AppColors.surfaceLow,
      borderRadius: BorderRadius.circular(20),
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(
          enabled ? Icons.check : Icons.notifications_off_outlined,
          size: 12,
          color: AppColors.primary,
        ),
        const SizedBox(width: 4),
        Text(
          '$label${enabled ? '' : ' uit'}',
          style: const TextStyle(fontSize: 10, color: AppColors.primary),
        ),
      ],
    ),
  );
}
