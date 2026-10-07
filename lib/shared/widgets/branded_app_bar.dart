import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_tokens.dart';
import 'radar_logo.dart';
import 'privacy_action.dart';
import 'notifications_action.dart';
import 'profile_action.dart';

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

    // Toon een duidelijke terugpijl zodra er iets te poppen valt (gepushte schermen).
    final effectiveLeading =
        leading ??
        (Navigator.of(context).canPop()
            ? IconButton(
                icon: const Icon(Icons.arrow_back),
                tooltip: 'Terug',
                onPressed: () => Navigator.of(context).maybePop(),
              )
            : null);

    return AppBar(
      leadingWidth: effectiveLeading == null ? 0 : null,
      leading: effectiveLeading,
      titleSpacing: effectiveLeading == null ? tokens.spaceMd : 0,
      title: Row(
        children: [
          const RadarLogo(),
          SizedBox(width: tokens.spaceSm + tokens.spaceXs),
          Flexible(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('THUISRADAR', style: text.labelSmall?.copyWith(color: AppColors.muted)),
                Text(title, style: text.titleLarge),
              ],
            ),
          ),
        ],
      ),
      actions: [
        const PrivacyAction(),
        const NotificationsAction(),
        ...actions,
        if (actions.isEmpty && title != 'Profiel & instellingen') const ProfileAction(),
        SizedBox(width: tokens.spaceSm),
      ],
    );
  }
}
