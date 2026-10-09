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

  /// Gezinsleden van wie de batterijwaarschuwing al gezien is.
  Future<Set<String>> seenLowBattery(String familyId) async {
    final prefs = await SharedPreferences.getInstance();
    return (prefs.getStringList(_batteryKey(familyId)) ?? const []).toSet();
  }

  /// Vervangt de lijst; wie intussen weer opgeladen is, valt er zo vanzelf uit.
  Future<void> setSeenLowBattery(String familyId, Set<String> userIds) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(_batteryKey(familyId), userIds.toList());
  }

  String _key(String familyId) => 'events_cleared_$familyId';
  String _batteryKey(String familyId) => 'low_battery_seen_$familyId';
}
