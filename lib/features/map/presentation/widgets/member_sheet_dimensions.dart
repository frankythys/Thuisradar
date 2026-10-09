import 'package:flutter/material.dart';

import '../../../../core/theme/app_tokens.dart';
import '../../../../shared/widgets/icon_filter_chips.dart';

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

  /// De uitnodigingskaart staat enkel bovenaan zolang je nog alleen in het
  /// gezin zit; bij een actief gezin begint het paneel met de gezinsnaam.
  /// Een lege lijst betekent "nog aan het laden" (je bent zelf altijd lid).
  static bool showsInvite({required bool canInvite, required int memberCount}) =>
      canInvite && memberCount == 1;

  /// Vaste kop: greep, eventueel de uitnodigingskaart, gezinsnaam en knoppen.
  static double headerHeight(
    BuildContext context,
    double width, {
    required String familyName,
    required bool showInvite,
  }) {
    final tokens = context.tokens;
    final painter = TextPainter(
      text: TextSpan(text: familyName, style: Theme.of(context).textTheme.headlineMedium),
      textDirection: Directionality.of(context),
      textScaler: MediaQuery.textScalerOf(context),
    )..layout(maxWidth: (width - 2 * tokens.spaceMd).clamp(1.0, double.infinity));
    final name = painter.height;
    painter.dispose();
    var result =
        2 * tokens.spaceSm + _handle + tokens.spaceMd + name + tokens.spaceMd + IconFilterChips.chipHeight;
    if (showInvite) result += inviteHeight(context, width) + tokens.spaceLg;
    return result.ceilToDouble();
  }

  /// Ingeklapte hoogte. Alleen in het gezin: greep + uitnodigingskaart. Bij een
  /// actief gezin: enkel gezinsnaam en knoppen, zodat de kaart zo groot
  /// mogelijk blijft.
  static double collapsedHeight(
    BuildContext context,
    double width, {
    required String familyName,
    required bool showInvite,
  }) {
    final tokens = context.tokens;
    if (showInvite) return (2 * tokens.spaceSm + _handle + inviteHeight(context, width)).ceilToDouble();
    final header = headerHeight(context, width, familyName: familyName, showInvite: false);
    return (header + tokens.spaceSm).ceilToDouble();
  }

  static const _handle = 16.0;
}
