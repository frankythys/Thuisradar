/// De talen van de app. Nederlands is de brontaal; Engels is de terugvaltaal
/// voor elk toestel waarvan de taal hier niet tussen staat.
enum AppLanguage {
  nl('Nederlands'),
  en('English'),
  fr('Français'),
  de('Deutsch'),
  es('Español'),
  pt('Português'),
  it('Italiano'),
  tr('Türkçe');

  const AppLanguage(this.nativeName);

  /// Naam in de taal zelf, zodat iedereen zijn eigen taal herkent.
  final String nativeName;

  /// ISO 639-1-code, gelijk aan de naam van het `.arb`-bestand.
  String get code => name;

  static const fallback = AppLanguage.en;

  /// Taal voor een code als `nl`, `nl-BE` of `pt_BR`; `null` als we die niet
  /// ondersteunen.
  static AppLanguage? fromCode(String? code) {
    if (code == null || code.isEmpty) return null;
    final language = code.split(RegExp('[-_]')).first.toLowerCase();
    for (final value in values) {
      if (value.code == language) return value;
    }
    return null;
  }
}

/// Kiest de taal van de app: eerst de eigen keuze in Profiel, anders de eerste
/// ondersteunde taal uit de voorkeurslijst van het toestel, anders Engels.
AppLanguage resolveAppLanguage({String? override, required Iterable<String> deviceLanguages}) {
  final chosen = AppLanguage.fromCode(override);
  if (chosen != null) return chosen;
  for (final code in deviceLanguages) {
    final language = AppLanguage.fromCode(code);
    if (language != null) return language;
  }
  return AppLanguage.fallback;
}
