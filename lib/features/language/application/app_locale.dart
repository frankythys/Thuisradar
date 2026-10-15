import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import '../../../l10n/l10n.dart';
import '../domain/app_language.dart';

/// Alles wat een MaterialApp nodig heeft om in de juiste taal te draaien;
/// app.dart en de widgettests gebruiken precies dezelfde instellingen.
abstract final class AppLocale {
  static const delegates = <LocalizationsDelegate<Object>>[
    AppLocalizations.delegate,
    GlobalMaterialLocalizations.delegate,
    GlobalWidgetsLocalizations.delegate,
    GlobalCupertinoLocalizations.delegate,
  ];

  static final supported = [for (final language in AppLanguage.values) Locale(language.code)];

  /// De eigen keuze als [Locale]; `null` laat Flutter de toesteltaal nemen.
  static Locale? of(AppLanguage? chosen) => chosen == null ? null : Locale(chosen.code);

  /// Toesteltaal → eerste ondersteunde taal uit de voorkeurslijst, anders Engels.
  static Locale resolve(List<Locale>? device, Iterable<Locale> supported) => Locale(
    resolveAppLanguage(
      deviceLanguages: [for (final locale in device ?? const <Locale>[]) locale.languageCode],
    ).code,
  );
}
