import 'package:supabase_flutter/supabase_flutter.dart';

import '../domain/member_location.dart';

class LocationRepository {
  LocationRepository(this._client);

  final SupabaseClient _client;

  Future<void> upload(MemberLocation location) {
    return _client.from('member_locations').upsert(location.toJson(), onConflict: 'user_id');
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
