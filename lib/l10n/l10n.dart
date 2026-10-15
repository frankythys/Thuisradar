import 'package:flutter/widgets.dart';

import 'generated/app_localizations.dart';
import 'l10n.dart';

export 'generated/app_localizations.dart';

extension AppLocalizationsNames on AppLocalizations {
  /// "Oma", "Oma en Jan", "Oma, Jan en Liam" in de taal van de app.
  String joinNames(Iterable<String> names) {
    final list = names.toList();
    if (list.length < 2) return list.join();
    return commonListAnd(list.sublist(0, list.length - 1).join(', '), list.last);
  }
}

extension AppLocalizationsContext on BuildContext {
  /// Teksten in de taal van de app. Zonder [Localizations] in de boom (bv. een
  /// widgettest met een kale MaterialApp) val je terug op het Nederlands, de
  /// brontaal, in plaats van te crashen.
  AppLocalizations get l10n => AppLocalizations.of(this) ?? lookupAppLocalizations(const Locale('nl'));
}
