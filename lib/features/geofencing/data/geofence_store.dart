import 'dart:convert';
import 'dart:math';

import 'package:shared_preferences/shared_preferences.dart';

import '../domain/geofence_report.dart';

/// Wat de achtergrond-callback nodig heeft: de toestelsleutel en de wachtrij.
///
/// [SharedPreferencesAsync] heeft geen cache per isolate, zodat de app en de
/// achtergrond-callback altijd dezelfde waarden zien.
class GeofenceStore {
  GeofenceStore([SharedPreferencesAsync? prefs]) : _prefs = prefs ?? SharedPreferencesAsync();

  final SharedPreferencesAsync _prefs;

  static const _keyName = 'geofence_device_key';
  static const _queueName = 'geofence_pending_reports';

  Future<String?> deviceKey() => _prefs.getString(_keyName);

  /// Bestaande sleutel, of een nieuwe willekeurige (256 bit).
  Future<String> ensureDeviceKey() async {
    final existing = await deviceKey();
    if (existing != null) return existing;
    final random = Random.secure();
    final key = base64UrlEncode(List<int>.generate(32, (_) => random.nextInt(256)));
    await _prefs.setString(_keyName, key);
    return key;
  }

  Future<List<GeofenceReport>> pending() async {
    final raw = await _prefs.getString(_queueName);
    if (raw == null) return const [];
    try {
      return [
        for (final item in jsonDecode(raw) as List<dynamic>)
          GeofenceReport.fromJson(item as Map<String, dynamic>),
      ];
    } on FormatException {
      return const [];
    }
  }

  Future<void> savePending(List<GeofenceReport> reports) => reports.isEmpty
      ? _prefs.remove(_queueName)
      : _prefs.setString(_queueName, jsonEncode([for (final r in reports) r.toJson()]));

  /// Afmelden of delen uit: sleutel en wachtrij weg.
  Future<void> clear() async {
    await _prefs.remove(_keyName);
    await _prefs.remove(_queueName);
  }
}
