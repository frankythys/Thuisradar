import 'package:flutter/material.dart';

import '../../../core/theme/app_tokens.dart';
import '../../../core/utils/time_format.dart';
import '../../../l10n/l10n.dart';
import '../domain/parked_car.dart';

enum ParkedCarAction { navigate, show, save, remove }

/// Onderblad bij een parkeerplek. Van iemand anders: navigeren of tonen.
/// Van jezelf ook bijwerken of verwijderen; zonder plek enkel opslaan.
Future<ParkedCarAction?> showParkedCarSheet(
  BuildContext context, {
  required ParkedCar? car,
  required bool mine,
  String? ownerName,
}) {
  return showModalBottomSheet<ParkedCarAction>(
    context: context,
    // Mag hoger dan de helft van het scherm, en scrolt op een klein toestel.
    isScrollControlled: true,
    showDragHandle: true,
    builder: (context) {
      final l10n = context.l10n;
      final tokens = context.tokens;
      final colors = Theme.of(context).colorScheme;
      final title = mine || ownerName == null ? l10n.parkedCarTitle : l10n.parkedCarOf(ownerName);
      Widget option(ParkedCarAction action, IconData icon, String label, {bool danger = false}) => ListTile(
        leading: Icon(icon, color: danger ? colors.error : colors.primary),
        title: Text(label, style: danger ? TextStyle(color: colors.error) : null),
        onTap: () => Navigator.pop(context, action),
      );
      return SafeArea(
        child: SingleChildScrollView(
          child: Padding(
            padding: EdgeInsets.fromLTRB(tokens.spaceLg, 0, tokens.spaceLg, tokens.spaceMd),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(title, style: Theme.of(context).textTheme.titleLarge),
                SizedBox(height: tokens.spaceXs),
                Text(
                  car == null
                      ? l10n.parkedCarInfo
                      : l10n.parkedCarLastSaved(formatRelative(l10n, car.parkedAt, now: DateTime.now())),
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: colors.onSurfaceVariant),
                ),
                SizedBox(height: tokens.spaceSm),
                if (car != null) ...[
                  option(ParkedCarAction.navigate, Icons.directions_walk, l10n.parkedCarNavigate),
                  option(ParkedCarAction.show, Icons.map_outlined, l10n.parkedCarShowAction),
                ],
                if (mine) ...[
                  option(
                    ParkedCarAction.save,
                    Icons.edit_location_alt_outlined,
                    car == null ? l10n.parkedCarSaveAction : l10n.parkedCarUpdateAction,
                  ),
                  if (car != null)
                    option(
                      ParkedCarAction.remove,
                      Icons.delete_outline,
                      l10n.parkedCarDeleteAction,
                      danger: true,
                    ),
                ],
              ],
            ),
          ),
        ),
      );
    },
  );
}
