import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';

/// Secundaire actie-chip: pil met primaryContainer-achtergrond en teal tekst
/// (DESIGN.md: hoogte 40). Optioneel leidend icoon.
class SecondaryChip extends StatelessWidget {
  const SecondaryChip({super.key, required this.label, required this.onPressed, this.icon});

  final String label;
  final VoidCallback onPressed;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final textStyle = Theme.of(context).textTheme.labelLarge?.copyWith(color: AppColors.primary);

    return TextButton.icon(
      onPressed: onPressed,
      icon: icon == null ? const SizedBox.shrink() : Icon(icon, size: 18, color: AppColors.primary),
      label: Text(label),
      style: TextButton.styleFrom(
        backgroundColor: AppColors.primarySoft,
        foregroundColor: AppColors.primary,
        textStyle: textStyle,
        minimumSize: const Size(0, 40),
        padding: const EdgeInsets.symmetric(horizontal: 16),
        shape: const StadiumBorder(),
      ),
    );
  }
}
