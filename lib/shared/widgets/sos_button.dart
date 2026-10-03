import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';

/// Noodknop in burnt-orange pil-vorm (DESIGN.md: hoogte 56, volledig rond).
class SosButton extends StatelessWidget {
  const SosButton({super.key, required this.onPressed, this.label = 'SOS', this.compact = false});

  final VoidCallback onPressed;
  final String label;

  /// Compacte variant (bv. zwevend op de kaart) vs. volle breedte.
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final textStyle = Theme.of(context).textTheme.labelLarge?.copyWith(color: Colors.white);

    return FilledButton.icon(
      onPressed: onPressed,
      icon: const Icon(Icons.shield_outlined, size: 20),
      label: Text(label),
      style: FilledButton.styleFrom(
        backgroundColor: AppColors.alert,
        foregroundColor: Colors.white,
        textStyle: textStyle,
        minimumSize: compact ? const Size(0, 44) : const Size.fromHeight(56),
        padding: compact ? const EdgeInsets.symmetric(horizontal: 18) : null,
        shape: const StadiumBorder(),
      ),
    );
  }
}
