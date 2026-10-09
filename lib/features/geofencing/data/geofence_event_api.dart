import 'package:supabase_flutter/supabase_flutter.dart';

import '../domain/geofence_report.dart';

/// Kon niet verstuurd worden; [retry] = later opnieuw proberen (geen netwerk,
/// server even weg, migratie 014 nog niet gedraaid).
class GeofenceSendException implements Exception {
  const GeofenceSendException(this.message, {required this.retry});

  final String message;
  final bool retry;

  @override
  String toString() => 'GeofenceSendException($message, retry: $retry)';
}

/// Stuurt een aankomst/vertrek naar `record_geofence_event` (migratie 014).
///
/// Draait ook in de achtergrond-callback, zonder ingelogde sessie: de client
/// gebruikt enkel de publieke sleutel, de toestelsleutel bewijst wie het is.
class GeofenceEventApi {
  GeofenceEventApi(this._client);

  final SupabaseClient _client;

  static const _timeout = Duration(seconds: 15);

  /// Geeft het antwoord van de server terug, bv. `recorded` of `duplicate`.
  Future<String> send({required String deviceKey, required GeofenceReport report}) async {
    try {
      final result = await _client
          .rpc<dynamic>(
            'record_geofence_event',
            params: {
              'p_key': deviceKey,
              'p_place_id': report.placeId,
              'p_type': report.type.name,
              'p_lat': report.latitude,
              'p_lng': report.longitude,
              'p_at': report.at.toUtc().toIso8601String(),
            },
          )
          .timeout(_timeout);
      return result.toString();
    } on PostgrestException catch (error) {
      // PGRST202 = functie bestaat (nog) niet: migratie 014 later alsnog.
      throw GeofenceSendException(error.message, retry: error.code == 'PGRST202');
    } on Exception catch (error) {
      throw GeofenceSendException(error.toString(), retry: true);
    }
  }
}
