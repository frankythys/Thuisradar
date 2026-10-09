import 'package:flutter/material.dart';

import '../../core/theme/app_tokens.dart';
import 'radar_logo.dart';
import 'notifications_action.dart';
import 'profile_action.dart';

/// Rustige app-balk: logotegel en titel, rechts het belletje, eventuele
/// eigen acties en anders je eigen avatar. Hergebruikt op bijna elk scherm.
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
          const RadarLogo(size: 32),
          SizedBox(width: tokens.spaceSm + tokens.spaceXs),
          Flexible(
            child: Text(title, style: text.titleLarge, maxLines: 1, overflow: TextOverflow.ellipsis),
          ),
        ],
      ),
      actions: [
        const NotificationsAction(),
        ...actions,
        if (actions.isEmpty && title != 'Profiel') const ProfileAction(),
        SizedBox(width: tokens.spaceSm),
      ],
    );
  }
}
