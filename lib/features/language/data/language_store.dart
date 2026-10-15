import 'package:shared_preferences/shared_preferences.dart';

/// Bewaart de eigen taalkeuze op dit toestel (los van de gebruiker: een
/// gedeelde gsm houdt dezelfde taal). Geen keuze = de toesteltaal volgen.
class LanguageStore {
  static const _key = 'app_language';

  Future<String?> read() async => (await SharedPreferences.getInstance()).getString(_key);

  Future<void> write(String? code) async {
    final prefs = await SharedPreferences.getInstance();
    if (code == null) {
      await prefs.remove(_key);
    } else {
      await prefs.setString(_key, code);
    }
  }
}
