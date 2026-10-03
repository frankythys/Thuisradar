import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_tokens.dart';

/// App-balk met de Thuisradar-logotegel, een kleine merknaam-overline en een
/// titel, plus optionele acties rechts. Hergebruikt op bijna elk hoofdscherm.
class BrandedAppBar extends StatelessWidget implements PreferredSizeWidget {
  const BrandedAppBar({super.key, required this.title, this.actions = const [], this.leading});

  final String title;
  final List<Widget> actions;

  /// Bv. een terug-knop; standaard geen leading.
  final Widget? leading;

  @override
  Size get preferredSize => const Size.fromHeight(64);

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final tokens = context.tokens;

    return AppBar(
      leadingWidth: leading == null ? 0 : null,
      leading: leading,
      titleSpacing: leading == null ? tokens.spaceMd : 0,
      title: Row(
        children: [
          const _LogoTile(),
          SizedBox(width: tokens.spaceSm + tokens.spaceXs),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('THUISRADAR', style: text.labelSmall?.copyWith(color: AppColors.muted)),
              Text(title, style: text.titleLarge),
            ],
          ),
        ],
      ),
      actions: [
        ...actions,
        SizedBox(width: tokens.spaceSm),
      ],
    );
  }
}

class _LogoTile extends StatelessWidget {
  const _LogoTile();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 40,
      height: 40,
      decoration: BoxDecoration(
        color: AppColors.primary,
        borderRadius: BorderRadius.circular(context.tokens.radiusMd),
      ),
      child: const Icon(Icons.home_rounded, color: Colors.white, size: 22),
    );
  }
}
