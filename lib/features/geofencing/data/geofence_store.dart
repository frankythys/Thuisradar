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
  static const _reportPrefix = 'geofence_report_v2_';

  String _prefix(String deviceKey) => '$_reportPrefix${deviceKey}_';

  String _reportKey(String deviceKey, GeofenceReport report) =>
      '${_prefix(deviceKey)}${base64UrlEncode(utf8.encode(jsonEncode(report.toJson())))}';

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

  /// Elke melding heeft een eigen sleutel: geen gedeelde read-modify-write-lijst
  /// die vanuit een andere isolate overschreven kan worden. De toestelnaamruimte
  /// voorkomt dat een oude callback meldingen aan een nieuw account doorgeeft.
  Future<void> enqueue(String deviceKey, List<GeofenceReport> reports) async {
    for (final report in reports) {
      await _prefs.setString(_reportKey(deviceKey, report), jsonEncode(report.toJson()));
    }
  }

  Future<void> acknowledge(String deviceKey, GeofenceReport report) =>
      _prefs.remove(_reportKey(deviceKey, report));

  Future<List<GeofenceReport>> pending(String deviceKey) async {
    // Bestaande offline meldingen éénmalig overnemen bij een app-update.
    final raw = await _prefs.getString(_queueName);
    if (raw != null && await this.deviceKey() == deviceKey) {
      try {
        await enqueue(deviceKey, [
          for (final item in jsonDecode(raw) as List<dynamic>)
            GeofenceReport.fromJson(item as Map<String, dynamic>),
        ]);
      } on FormatException {
        // Ongeldige oude wachtrij kan niet gemigreerd worden.
      }
      await _prefs.remove(_queueName);
    }
    final reports = <GeofenceReport>[];
    for (final entry in (await _prefs.getAll()).entries) {
      if (entry.key.startsWith(_prefix(deviceKey))) {
        reports.add(GeofenceReport.fromJson(jsonDecode(entry.value as String) as Map<String, dynamic>));
      }
    }
    return reports;
  }

  /// Afmelden of delen uit: sleutel en wachtrij weg.
  Future<void> clear() async {
    await _prefs.remove(_keyName);
    await _prefs.remove(_queueName);
    for (final key in await _prefs.getKeys()) {
      if (key.startsWith(_reportPrefix)) await _prefs.remove(key);
    }
  }
}
