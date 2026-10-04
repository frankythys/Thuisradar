import 'package:shared_preferences/shared_preferences.dart';

/// Toestelvoorkeuren; de deelkeuze wordt ook vóór het starten van GPS gelezen.
class ProfilePreferences {
  String key(String userId, String field) => 'profile_${userId}_$field';
  Future<bool> sharing(String userId) async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(key(userId, 'sharing')) ?? true;
  }

  Future<void> setSharing(String userId, bool enabled) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(key(userId, 'sharing'), enabled);
  }
}
