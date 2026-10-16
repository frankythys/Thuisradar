import 'package:flutter/material.dart';

import '../../core/theme/app_tokens.dart';

/// Eén keuze in een [IconFilterChips]-rij.
class IconFilterItem {
  const IconFilterItem({required this.icon, required this.label});

  final IconData icon;

  /// Naam voor schermlezers en tooltip.
  final String label;
}

/// Rij ronde icoon-chips in de app-kleur: de gekozen chip is gevuld, de rest
/// wit met een rand in de app-kleur (zoals de ronde kaartknoppen).
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

  /// Vaste hoogte van de rij, zodat een vastgezette kop deze kan meenemen.
  static const double chipHeight = 44;

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;

    return Row(
      children: [
        for (final (index, item) in items.indexed)
          Padding(
            padding: EdgeInsets.only(right: tokens.spaceSm),
            child: _Chip(item: item, selected: index == selectedIndex, onTap: () => onSelected(index)),
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
    final primary = Theme.of(context).colorScheme.primary;
    final color = selected ? Theme.of(context).colorScheme.onPrimary : primary;

    return Tooltip(
      message: item.label,
      child: Semantics(
        label: item.label,
        selected: selected,
        button: true,
        child: Material(
          color: selected ? primary : Theme.of(context).colorScheme.surface,
          shape: StadiumBorder(
            side: BorderSide(color: primary, width: tokens.spaceXs / 2),
          ),
          child: InkWell(
            onTap: onTap,
            customBorder: const StadiumBorder(),
            child: SizedBox(
              height: IconFilterChips.chipHeight,
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
