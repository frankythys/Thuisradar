import 'package:flutter/material.dart';

import '../../../../core/theme/app_tokens.dart';

/// Hoogtes volgen de beschikbare breedte en de tekstgrootte van het toestel.
abstract final class MemberSheetDimensions {
  static double inviteHeight(BuildContext context, double width) {
    final tokens = context.tokens;
    final text = Theme.of(context).textTheme;
    final labelWidth = (width - 5 * tokens.spaceMd - 48).clamp(1.0, double.infinity);
    double height(String label, TextStyle? style) {
      final painter = TextPainter(
        text: TextSpan(text: label, style: style),
        textDirection: Directionality.of(context),
        textScaler: MediaQuery.textScalerOf(context),
      )..layout(maxWidth: labelWidth);
      final result = painter.height;
      painter.dispose();
      return result;
    }

    final labels =
        height('Nodig anderen uit, blijf samen veiliger', text.titleMedium) +
        tokens.spaceXs +
        height('Dierbaren toevoegen', text.labelLarge);
    return labels.clamp(48.0, double.infinity) + 2 * tokens.spaceMd;
  }

  static double collapsedHeight(BuildContext context, double width) =>
      (2 * context.tokens.spaceSm + 16 + inviteHeight(context, width)).ceilToDouble();
}
