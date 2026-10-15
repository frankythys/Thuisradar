/// Functies die standaard uit staan. Aanzetten via `env.json`, bv.
/// `"USE_GOOGLE_MAPS": "true"`, en de app opnieuw bouwen.
abstract final class FeatureFlags {
  /// Google Maps (met satelliet) als kaartachtergrond in plaats van
  /// OpenStreetMap. Vereist `MAPS_API_KEY` in `android/local.properties`.
  /// Kaartweergave via de Maps SDK for Android is gratis (zie docs/KOSTEN.md).
  static const useGoogleMaps = bool.fromEnvironment('USE_GOOGLE_MAPS');

  /// Activiteitsherkenning van het toestel (auto / fiets / te voet) als extra
  /// signaal naast GPS-snelheid en stappen. Gratis (Play Services /
  /// CoreMotion). Vereist migratie `020_activity.sql`; zonder die migratie
  /// blijft delen werken, alleen zonder herkenning.
  static const useActivityRecognition = bool.fromEnvironment('USE_ACTIVITY_RECOGNITION');
}
