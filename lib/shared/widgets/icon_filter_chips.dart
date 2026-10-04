import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_tokens.dart';

/// Eén keuze in een [IconFilterChips]-rij.
class IconFilterItem {
  const IconFilterItem({required this.icon, required this.label});

  final IconData icon;

  /// Naam voor schermlezers en tooltip.
  final String label;
}

/// Rij ronde icoon-chips; de gekozen chip is donker gevuld, de rest wit.
/// Gecontroleerd: de ouder houdt de gekozen index bij.
class IconFilterChips extends StatelessWidget {
  const IconFilterChips({
    super.key,
    required this.items,
    required this.selectedIndex,
    required this.onSelected,
  });

  final List<IconFilterItem> items;
  final int selectedIndex;
  final ValueChanged<int> onSelected;

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;

    return Row(
      children: [
        for (final (index, item) in items.indexed)
          Padding(
            padding: EdgeInsets.only(right: tokens.spaceSm),
            child: _Chip(
              item: item,
              selected: index == selectedIndex,
              onTap: () => onSelected(index),
            ),
          ),
      ],
    );
  }
}

class _Chip extends StatelessWidget {
  const _Chip({required this.item, required this.selected, required this.onTap});

  final IconFilterItem item;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    final color = selected ? Colors.white : AppColors.ink;

    return Tooltip(
      message: item.label,
      child: Semantics(
        label: item.label,
        selected: selected,
        button: true,
        child: Material(
          color: selected ? AppColors.ink : Colors.white,
          shape: StadiumBorder(
            side: selected
                ? BorderSide.none
                : const BorderSide(color: AppColors.border),
          ),
          child: InkWell(
            onTap: onTap,
            customBorder: const StadiumBorder(),
            child: SizedBox(
              height: 44,
              child: Padding(
                padding: EdgeInsets.symmetric(horizontal: tokens.spaceLg),
                child: Icon(item.icon, size: 20, color: color),
              ),
            ),
          ),
        ),
      ),
    );
  }
}