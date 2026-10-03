import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_tokens.dart';

/// Rij selecteerbare pil-chips (bv. Vandaag / Gisteren / Wo 30 sep).
/// Gecontroleerd: de ouder houdt de geselecteerde index bij.
class FilterChips extends StatelessWidget {
  const FilterChips({super.key, required this.labels, required this.selectedIndex, required this.onSelected});

  final List<String> labels;
  final int selectedIndex;
  final ValueChanged<int> onSelected;

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          for (final (index, label) in labels.indexed)
            Padding(
              padding: EdgeInsets.only(right: tokens.spaceSm),
              child: _Chip(label: label, selected: index == selectedIndex, onTap: () => onSelected(index)),
            ),
        ],
      ),
    );
  }
}

class _Chip extends StatelessWidget {
  const _Chip({required this.label, required this.selected, required this.onTap});

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final textStyle = Theme.of(context).textTheme.labelLarge
        ?.copyWith(color: selected ? Colors.white : AppColors.ink);

    return Material(
      color: selected ? AppColors.primary : Colors.white,
      shape: const StadiumBorder(),
      child: InkWell(
        onTap: onTap,
        customBorder: const StadiumBorder(),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
          child: Text(label, style: textStyle),
        ),
      ),
    );
  }
}
