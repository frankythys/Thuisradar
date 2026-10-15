import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../l10n/l10n.dart';

/// De hoofdtabs: Kaart, Onderweg (rijden, fietsen, wandelen), Plaatsen, Chat. Meldingen zit als belletje in
/// de app-balk bovenaan.
enum AppTab { kaart, rijden, plaatsen, chat }

/// Onderste navigatiebalk in de Thuisradar-stijl (actief = teal met
/// primaryContainer-indicator).
class AppBottomNav extends StatelessWidget {
  const AppBottomNav({
    super.key,
    required this.current,
    required this.onSelected,
    this.offline = false,
    this.onFamily,
    this.onSettings,
  });

  final bool offline;
  final VoidCallback? onFamily;
  final VoidCallback? onSettings;
  final AppTab current;
  final ValueChanged<AppTab> onSelected;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final l10n = context.l10n;

    return NavigationBarTheme(
      data: NavigationBarThemeData(
        backgroundColor: AppColors.ground,
        indicatorColor: AppColors.primarySoft,
        labelTextStyle: WidgetStateProperty.resolveWith((states) {
          final selected = states.contains(WidgetState.selected);
          return text.labelMedium?.copyWith(color: selected ? AppColors.primary : AppColors.muted);
        }),
        iconTheme: WidgetStateProperty.resolveWith((states) {
          final selected = states.contains(WidgetState.selected);
          return IconThemeData(color: selected ? AppColors.primary : AppColors.muted);
        }),
      ),
      child: NavigationBar(
        height: 72,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        selectedIndex: offline
            ? switch (current) {
                AppTab.plaatsen => 2,
                _ => 0,
              }
            : current.index,
        onDestinationSelected: (index) {
          if (!offline) {
            onSelected(AppTab.values[index]);
            return;
          }
          switch (index) {
            case 0:
              onSelected(AppTab.kaart);
            case 1:
              onFamily?.call();
            case 2:
              onSelected(AppTab.plaatsen);
            case 3:
              onSettings?.call();
          }
        },
        destinations: offline
            ? [
                NavigationDestination(icon: const Icon(Icons.map_outlined), label: l10n.navMap),
                NavigationDestination(icon: const Icon(Icons.groups_outlined), label: l10n.navFamily),
                NavigationDestination(icon: const Icon(Icons.place_outlined), label: l10n.navPlaces),
                NavigationDestination(icon: const Icon(Icons.settings_outlined), label: l10n.navSettings),
              ]
            : [
                NavigationDestination(
                  icon: const Icon(Icons.map_outlined),
                  selectedIcon: const Icon(Icons.map),
                  label: l10n.navMap,
                ),
                NavigationDestination(
                  icon: const Icon(Icons.route_outlined),
                  selectedIcon: const Icon(Icons.route),
                  label: l10n.navOnTheMove,
                ),
                NavigationDestination(
                  icon: const Icon(Icons.place_outlined),
                  selectedIcon: const Icon(Icons.place),
                  label: l10n.navPlaces,
                ),
                NavigationDestination(
                  icon: const Icon(Icons.chat_bubble_outline),
                  selectedIcon: const Icon(Icons.chat_bubble),
                  label: l10n.navChat,
                ),
              ],
      ),
    );
  }
}
