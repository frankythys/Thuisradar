import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_tokens.dart';

/// Eén rij in de instellingenlijst: icoon, titel, optionele uitleg en iets
/// rechts (standaard een pijltje als de rij aantikbaar is).
class ProfileTile extends StatelessWidget {
  const ProfileTile({
    super.key,
    required this.icon,
    required this.title,
    this.subtitle,
    this.trailing,
    this.onTap,
    this.danger = false,
  });

  final IconData icon;
  final String title;
  final String? subtitle;
  final Widget? trailing;
  final VoidCallback? onTap;

  /// Rood (bv. "Familie verlaten").
  final bool danger;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final tokens = context.tokens;
    final color = danger ? AppColors.alert : AppColors.primary;
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: tokens.spaceMd, vertical: tokens.spaceSm + tokens.spaceXs),
        child: Row(
          children: [
            Icon(icon, color: color),
            SizedBox(width: tokens.spaceMd),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: text.titleSmall?.copyWith(color: danger ? AppColors.alert : null)),
                  if (subtitle != null)
                    Text(subtitle!, style: text.bodySmall?.copyWith(color: AppColors.muted)),
                ],
              ),
            ),
            ?trailing ??
                (onTap == null || danger ? null : const Icon(Icons.chevron_right, color: AppColors.muted)),
          ],
        ),
      ),
    );
  }
}
