import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_tokens.dart';
import '../../../../core/utils/time_format.dart';
import '../../../../shared/widgets/battery_badge.dart';
import '../../../../shared/widgets/member_avatar.dart';
import '../../../places/domain/place_status.dart';
import '../../domain/member_on_map.dart';

/// Compact kaartje dat verschijnt wanneer je een lid kiest (lijst of marker):
/// avatar, naam, status en batterij, met een knop naar de geschiedenis.
class MemberInfoCard extends StatelessWidget {
  const MemberInfoCard({
    super.key,
    required this.entry,
    required this.now,
    required this.onHistory,
    required this.onClose,
    this.placeStatus,
  });

  final MemberOnMap entry;
  final DateTime now;
  final VoidCallback onHistory;
  final VoidCallback onClose;
  final PlaceStatus? placeStatus;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final tokens = context.tokens;
    final location = entry.location;

    return DecoratedBox(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(tokens.radiusCard),
        boxShadow: tokens.shadowLevel2,
      ),
      child: Padding(
        padding: EdgeInsets.all(tokens.spaceMd),
        child: Row(
          children: [
            MemberAvatar(
              member: entry.member,
              size: 48,
              statusColor: location == null ? null : AppColors.primary,
            ),
            SizedBox(width: tokens.spaceMd),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    children: [
                      Expanded(child: Text(entry.member.displayName, style: text.titleMedium)),
                      BatteryBadge(level: location?.battery, isCharging: location?.isCharging),
                    ],
                  ),
                  SizedBox(height: tokens.spaceXs),
                  Text(_status(), style: text.bodySmall?.copyWith(color: AppColors.muted)),
                  SizedBox(height: tokens.spaceSm),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: FilledButton.icon(
                      onPressed: onHistory,
                      icon: const Icon(Icons.history, size: 18),
                      label: const Text('Geschiedenis'),
                      style: FilledButton.styleFrom(
                        backgroundColor: AppColors.primarySoft,
                        foregroundColor: AppColors.primary,
                        minimumSize: const Size(0, 40),
                        padding: EdgeInsets.symmetric(horizontal: tokens.spaceMd),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            IconButton(onPressed: onClose, tooltip: 'Sluiten', icon: const Icon(Icons.close)),
          ],
        ),
      ),
    );
  }

  String _status() {
    final location = entry.location;
    if (location == null) return 'Nog geen locatie gedeeld';

    final place = placeStatus;
    if (place != null) {
      return place.since == null ? place.name : '${place.name} · sinds ${formatClock(place.since!)}';
    }

    final updated = formatRelative(location.updatedAt, now: now);
    final speed = speedKmh(location.speedMps);
    return speed == null ? 'Bijgewerkt $updated' : 'Onderweg · $speed km/u · $updated';
  }
}
