import 'package:flutter/widgets.dart';

import 'generated/app_localizations.dart';

export 'generated/app_localizations.dart';

extension AppLocalizationsContext on BuildContext {
  /// Teksten in de taal van de app. Zonder [Localizations] in de boom (bv. een
  /// widgettest met een kale MaterialApp) val je terug op het Nederlands, de
  /// brontaal, in plaats van te crashen.
  AppLocalizations get l10n => AppLocalizations.of(this) ?? lookupAppLocalizations(const Locale('nl'));
}
