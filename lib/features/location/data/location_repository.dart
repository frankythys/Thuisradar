import 'package:supabase_flutter/supabase_flutter.dart';

import '../domain/member_location.dart';

class LocationRepository {
  LocationRepository(this._client);

  final SupabaseClient _client;

  /// Kolommen die pas met een migratie bestaan: `steps` (019) en `activity`
  /// (020). Hier staan de kolommen die de database nog niet kent.
  static const _optionalColumns = ['steps', 'activity'];
  final _missingColumns = <String>{};

  /// Uploadt de locatie. Kent de database een nieuwe kolom nog niet, dan
  /// opnieuw zonder: de locatie delen mag nooit stilvallen door de
  /// stappenteller of de activiteitsherkenning.
  Future<void> upload(MemberLocation location) async {
    final json = location.toJson()..removeWhere((key, _) => _missingColumns.contains(key));
    while (true) {
      try {
        await _client.from('member_locations').upsert(json, onConflict: 'user_id');
        return;
      } on PostgrestException catch (error) {
        final missing = _optionalColumns
            .where((column) => json.containsKey(column))
            .where((column) => isMissingColumn(error, column))
            .toList();
        if (missing.isEmpty) rethrow;
        _missingColumns.addAll(missing);
        json.removeWhere((key, _) => missing.contains(key));
      }
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

/// Fout omdat [column] ontbreekt: PostgREST kent hem niet in zijn schema
/// (PGRST204) of Postgres zelf niet (42703).
bool isMissingColumn(PostgrestException error, String column) =>
    (error.code == 'PGRST204' || error.code == '42703') && error.message.contains(column);

/// Fout omdat de kolom `steps` ontbreekt (migratie 019 niet gedraaid).
bool isMissingStepsColumn(PostgrestException error) => isMissingColumn(error, 'steps');
