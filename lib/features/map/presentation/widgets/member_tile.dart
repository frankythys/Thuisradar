import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/utils/time_format.dart';
import '../../../../shared/widgets/battery_indicator.dart';
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
    final location = entry.location;

    return ListTile(
      onTap: location == null ? null : onTap,
      minTileHeight: 64,
      contentPadding: const EdgeInsets.symmetric(horizontal: 4),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      leading: MemberAvatar(member: entry.member),
      title: Text.rich(
        TextSpan(
          text: entry.member.displayName,
          children: [
            if (isMe)
              const TextSpan(
                text: ' (jij)',
                style: TextStyle(fontWeight: FontWeight.w500, color: AppColors.muted),
              ),
          ],
        ),
        style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
      ),
      subtitle: Text(_status(), style: const TextStyle(color: AppColors.muted, fontSize: 13)),
      trailing: BatteryIndicator(level: location?.battery, isCharging: location?.isCharging),
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
