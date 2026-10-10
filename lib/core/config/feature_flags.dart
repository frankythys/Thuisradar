/// Functies die standaard uit staan. Aanzetten via `env.json`, bv.
/// `"USE_GOOGLE_MAPS": "true"`, en de app opnieuw bouwen.
abstract final class FeatureFlags {
  /// Google Maps (met satelliet) als kaartachtergrond in plaats van
  /// OpenStreetMap. Vereist `MAPS_API_KEY` in `android/local.properties`.
  /// Kaartweergave via de Maps SDK for Android is gratis (zie docs/KOSTEN.md).
  static const useGoogleMaps = bool.fromEnvironment('USE_GOOGLE_MAPS');
}
