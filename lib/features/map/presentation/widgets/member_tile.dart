import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_tokens.dart';
import '../../../../core/utils/time_format.dart';
import '../../../../shared/widgets/battery_badge.dart';
import '../../../../shared/widgets/member_avatar.dart';
import '../../domain/member_on_map.dart';

class MemberTile extends StatelessWidget {
  const MemberTile({super.key, required this.entry, required this.isMe, required this.now, this.onTap});

  final MemberOnMap entry;
  final bool isMe;
  final DateTime now;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final tokens = context.tokens;
    final location = entry.location;

    return Padding(
      padding: EdgeInsets.symmetric(vertical: tokens.spaceXs),
      child: Material(
        color: AppColors.ground,
        borderRadius: BorderRadius.circular(tokens.radiusCard),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(tokens.radiusCard),
          child: Padding(
            padding: EdgeInsets.all(tokens.spaceMd),
            child: Row(
              children: [
                MemberAvatar(member: entry.member, statusColor: location == null ? null : AppColors.primary),
                SizedBox(width: tokens.spaceMd),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        isMe ? '${entry.member.displayName} (jij)' : entry.member.displayName,
                        style: text.titleMedium,
                      ),
                      SizedBox(height: tokens.spaceXs),
                      Text(_status(), style: text.bodySmall?.copyWith(color: AppColors.muted)),
                    ],
                  ),
                ),
                SizedBox(width: tokens.spaceSm),
                BatteryBadge(level: location?.battery, isCharging: location?.isCharging),
                const Icon(Icons.chevron_right, color: AppColors.muted),
              ],
            ),
          ),
        ),
      ),
    );
  }

  String _status() {
    final location = entry.location;
    if (location == null) return 'Nog geen locatie gedeeld';

    final updated = formatRelative(location.updatedAt, now: now);
    final speed = speedKmh(location.speedMps);
    return speed == null ? 'Bijgewerkt $updated' : 'Onderweg · $speed km/u · $updated';
  }
}
