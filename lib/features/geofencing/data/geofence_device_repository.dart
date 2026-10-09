import 'package:supabase_flutter/supabase_flutter.dart';

/// Koppelt de toestelsleutel aan de ingelogde gebruiker (migratie 014).
class GeofenceDeviceRepository {
  GeofenceDeviceRepository(this._client);

  final SupabaseClient _client;

  Future<void> register(String deviceKey) =>
      _client.rpc<void>('register_geofence_device', params: {'p_key': deviceKey});

  Future<void> unregister(String deviceKey) =>
      _client.rpc<void>('unregister_geofence_device', params: {'p_key': deviceKey});
}
