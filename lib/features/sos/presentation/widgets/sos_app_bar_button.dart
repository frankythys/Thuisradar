import 'package:flutter/material.dart';

import '../../../../core/theme/app_tokens.dart';

/// Compacte SOS-pil in de app-balk, naast je avatar. Opent het noodscherm;
/// het alarm zelf gaat pas af na 3 seconden inhouden op dat scherm.
class SosAppBarButton extends StatelessWidget {
  const SosAppBarButton({super.key, required this.onPressed});

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final tokens = context.tokens;

    return Padding(
      padding: EdgeInsets.symmetric(horizontal: tokens.spaceXs),
      child: Tooltip(
        message: 'SOS-noodbericht',
        child: FilledButton.icon(
          onPressed: onPressed,
          style: FilledButton.styleFrom(
            backgroundColor: scheme.error,
            foregroundColor: scheme.onError,
            minimumSize: const Size(0, 36),
            padding: EdgeInsets.symmetric(horizontal: tokens.spaceSm + tokens.spaceXs),
            tapTargetSize: MaterialTapTargetSize.padded,
          ),
          icon: const Icon(Icons.warning_amber_rounded, size: 18),
          label: const Text('SOS'),
        ),
      ),
    );
  }
}
