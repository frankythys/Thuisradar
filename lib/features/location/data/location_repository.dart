import 'package:supabase_flutter/supabase_flutter.dart';

import '../domain/member_location.dart';

class LocationRepository {
  LocationRepository(this._client);

  final SupabaseClient _client;

  /// De database kent de kolom `steps` nog niet (migratie 019 niet gedraaid).
  bool _withoutSteps = false;

  /// Uploadt de locatie. Kent de database de stappen nog niet, dan opnieuw
  /// zonder: de locatie delen mag nooit stilvallen door de stappenteller.
  Future<void> upload(MemberLocation location) async {
    final json = location.toJson();
    if (_withoutSteps) json.remove('steps');
    try {
      await _client.from('member_locations').upsert(json, onConflict: 'user_id');
    } on PostgrestException catch (error) {
      if (!json.containsKey('steps') || !isMissingStepsColumn(error)) rethrow;
      _withoutSteps = true;
      await _client.from('member_locations').upsert(json..remove('steps'), onConflict: 'user_id');
    }
  }

  /// Realtime stroom van de laatste locatie van elk gezinslid.
  Stream<List<MemberLocation>> watchFamily(String familyId) {
    return _client
        .from('member_locations')
        .stream(primaryKey: ['user_id'])
        .eq('family_id', familyId)
        .map((rows) => rows.map(MemberLocation.fromJson).toList());
  }
}

/// Fout omdat de kolom `steps` ontbreekt: PostgREST kent hem niet in zijn
/// schema (PGRST204) of Postgres zelf niet (42703).
bool isMissingStepsColumn(PostgrestException error) =>
    (error.code == 'PGRST204' || error.code == '42703') && error.message.contains('steps');
