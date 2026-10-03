import 'package:flutter/material.dart';

import '../../core/theme/app_tokens.dart';

/// Witte kaart met zachte niveau-1-schaduw en 20px radius (DESIGN.md).
class AppCard extends StatelessWidget {
  const AppCard({super.key, required this.child, this.padding, this.onTap});

  final Widget child;
  final EdgeInsetsGeometry? padding;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    final radius = BorderRadius.circular(tokens.radiusCard);

    return DecoratedBox(
      decoration: BoxDecoration(color: Colors.white, borderRadius: radius, boxShadow: tokens.shadowLevel1),
      child: Material(
        type: MaterialType.transparency,
        child: InkWell(
          onTap: onTap,
          borderRadius: radius,
          child: Padding(padding: padding ?? EdgeInsets.all(tokens.spaceMd), child: child),
        ),
      ),
    );
  }
}
