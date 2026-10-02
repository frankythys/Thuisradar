/// Configuratie die bij het bouwen wordt meegegeven via
/// `--dart-define-from-file=env.json` (zie docs/SETUP.md).
abstract final class Env {
  static const supabaseUrl = String.fromEnvironment('SUPABASE_URL');

  /// De publieke "publishable key" (of de oudere "anon key") van Supabase.
  /// Nooit de service_role/secret key gebruiken: die hoort niet in een app.
  static const supabaseKey = String.fromEnvironment('SUPABASE_PUBLISHABLE_KEY');

  static void assertConfigured() {
    if (supabaseUrl.isEmpty || supabaseKey.isEmpty) {
      throw StateError(
        'SUPABASE_URL of SUPABASE_PUBLISHABLE_KEY ontbreekt. '
        'Start de app met --dart-define-from-file=env.json (zie docs/SETUP.md).',
      );
    }
  }
}
