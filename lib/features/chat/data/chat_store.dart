import 'package:shared_preferences/shared_preferences.dart';

/// Onthoudt tot wanneer de gebruiker de chat heeft gewist (per familie, lokaal
/// op dit toestel). De chat toont enkel berichten daarna.
class ChatStore {
  Future<DateTime?> clearedAt(String familyId) async {
    final prefs = await SharedPreferences.getInstance();
    final millis = prefs.getInt(_key(familyId));
    return millis == null ? null : DateTime.fromMillisecondsSinceEpoch(millis);
  }

  Future<void> clear(String familyId, DateTime at) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_key(familyId), at.millisecondsSinceEpoch);
  }

  String _key(String familyId) => 'chat_cleared_$familyId';
}
