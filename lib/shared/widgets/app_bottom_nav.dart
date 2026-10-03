import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';

/// De vier hoofdtabs: Kaart, Plaatsen, Chat, Meldingen.
enum AppTab { kaart, plaatsen, chat, meldingen }

/// Onderste navigatiebalk in de Thuisradar-stijl (actief = teal met
/// primaryContainer-indicator).
class AppBottomNav extends StatelessWidget {
  const AppBottomNav({super.key, required this.current, required this.onSelected, this.meldingenBadge = 0});

  final AppTab current;
  final ValueChanged<AppTab> onSelected;

  /// Aantal ongelezen meldingen (0 = geen badge).
  final int meldingenBadge;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;

    return NavigationBarTheme(
      data: NavigationBarThemeData(
        backgroundColor: Colors.white,
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
        selectedIndex: current.index,
        onDestinationSelected: (index) => onSelected(AppTab.values[index]),
        destinations: [
          const NavigationDestination(
            icon: Icon(Icons.map_outlined),
            selectedIcon: Icon(Icons.map),
            label: 'Kaart',
          ),
          const NavigationDestination(
            icon: Icon(Icons.place_outlined),
            selectedIcon: Icon(Icons.place),
            label: 'Plaatsen',
          ),
          const NavigationDestination(
            icon: Icon(Icons.chat_bubble_outline),
            selectedIcon: Icon(Icons.chat_bubble),
            label: 'Chat',
          ),
          NavigationDestination(
            icon: meldingenBadge > 0
                ? Badge(label: Text('$meldingenBadge'), child: const Icon(Icons.notifications_outlined))
                : const Icon(Icons.notifications_outlined),
            selectedIcon: const Icon(Icons.notifications),
            label: 'Meldingen',
          ),
        ],
      ),
    );
  }
}
