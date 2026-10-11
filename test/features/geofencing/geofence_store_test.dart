import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:thuisradar/features/geofencing/data/geofence_store.dart';
import 'package:thuisradar/features/geofencing/domain/geofence_report.dart';

class _Preferences extends Mock implements SharedPreferencesAsync {}

void main() {
  late _Preferences prefs;
  late Map<String, Object> values;
  final at = DateTime(2026, 10, 11);
  final a = GeofenceReport(placeId: 'A', type: GeofenceReportType.arrival, at: at);
  final b = GeofenceReport(placeId: 'B', type: GeofenceReportType.departure, at: at);

  setUp(() {
    prefs = _Preferences();
    values = {'geofence_device_key': 'device'};
    when(() => prefs.getString(any()))
        .thenAnswer((call) async => values[call.positionalArguments[0]] as String?);
    when(() => prefs.getAll()).thenAnswer((_) async => Map<String, Object>.of(values));
    when(() => prefs.getKeys()).thenAnswer((_) async => values.keys.toSet());
    when(() => prefs.setString(any(), any())).thenAnswer((call) async {
      values[call.positionalArguments[0] as String] = call.positionalArguments[1] as String;
    });
    when(() => prefs.remove(any())).thenAnswer((call) async {
      values.remove(call.positionalArguments[0]);
    });
  });

  test('twee stores bewaren apart; bevestigen van A verwijdert B niet', () async {
    final foreground = GeofenceStore(prefs);
    final background = GeofenceStore(prefs);
    await Future.wait([
      foreground.enqueue('device', [a]),
      background.enqueue('device', [b]),
    ]);
    await foreground.acknowledge('device', a);
    final remaining = await background.pending('device');
    expect(remaining.single.placeId, 'B');
    // Geen enkele operatie vervangt de volledige wachtrij.
    expect(values.keys.where((k) => k.startsWith('geofence_report_v2_')), hasLength(1));
  });

  test('oude offline wachtrij wordt overgenomen zonder nieuwe melding te wissen', () async {
    values['geofence_pending_reports'] = jsonEncode([a.toJson()]);
    final store = GeofenceStore(prefs);
    await store.enqueue('device', [b]);
    expect((await store.pending('device')).map((r) => r.placeId), unorderedEquals(['A', 'B']));
    expect(values.containsKey('geofence_pending_reports'), isFalse);
    expect((await GeofenceStore(prefs).pending('device')), hasLength(2));
  });

  test('late callback van oud toestel verschijnt niet bij een nieuwe sleutel', () async {
    final store = GeofenceStore(prefs);
    await store.enqueue('device', [a]);
    await store.clear();
    values['geofence_device_key'] = 'new-device';
    await store.enqueue('device', [b]);
    expect(await store.pending('new-device'), isEmpty);
  });
}
