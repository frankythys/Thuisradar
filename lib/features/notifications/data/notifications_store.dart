import 'package:shared_preferences/shared_preferences.dart';

/// Onthoudt tot wanneer de gebruiker zijn meldingen heeft gewist (per familie,
/// lokaal op dit toestel). De feed toont enkel gebeurtenissen daarna.
class NotificationsStore {
  Future<DateTime?> clearedAt(String familyId) async {
    final prefs = await SharedPreferences.getInstance();
    final millis = prefs.getInt(_key(familyId));
    return millis == null ? null : DateTime.fromMillisecondsSinceEpoch(millis);
  }

  Future<void> clear(String familyId, DateTime at) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_key(familyId), at.millisecondsSinceEpoch);
  }

  String _key(String familyId) => 'events_cleared_$familyId';
}
