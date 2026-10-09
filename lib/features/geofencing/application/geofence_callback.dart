import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/config/env.dart';
import '../data/geofence_event_api.dart';
import '../data/geofence_store.dart';
import '../data/native_geofence_source.dart';
import '../domain/geofence_report.dart';
import 'geofence_reporter.dart';

/// Android roept dit op bij het binnen- of buitengaan van een zone, ook als de
/// app dicht is. Het draait in een aparte isolate zonder Riverpod en zonder
/// ingelogde sessie: enkel de publieke sleutel en de toestelsleutel.
@pragma('vm:entry-point')
Future<void> onGeofenceTriggered(GeofenceCallbackParams params) async {
  final type = switch (params.event) {
    GeofenceEvent.enter => GeofenceReportType.arrival,
    GeofenceEvent.exit => GeofenceReportType.departure,
    GeofenceEvent.dwell => null,
  };
  if (type == null) return;

  final reports = reportsForZones(
    zoneIds: params.geofences.map((g) => g.id),
    type: type,
    at: DateTime.now(),
    latitude: params.location?.latitude,
    longitude: params.location?.longitude,
  );
  final client = SupabaseClient(
    Env.supabaseUrl,
    Env.supabaseKey,
    authOptions: const AuthClientOptions(autoRefreshToken: false),
  );
  try {
    final reporter = GeofenceReporter(store: GeofenceStore(), api: GeofenceEventApi(client));
    final answers = await reporter.report(reports);
    debugPrint('Zone ${type.name}: $answers');
  } on Object catch (error) {
    debugPrint('Zone-melding mislukt: $error');
  } finally {
    await client.dispose();
  }
}
