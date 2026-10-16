import 'package:supabase_flutter/supabase_flutter.dart';

import '../domain/parked_car.dart';

class ParkedCarRepository {
  ParkedCarRepository(this._client);

  final SupabaseClient _client;

  Stream<List<ParkedCar>> watchFamily(String familyId) => _client
      .from('parked_cars')
      .stream(primaryKey: ['user_id', 'family_id'])
      .eq('family_id', familyId)
      .map((rows) => rows.map(ParkedCar.fromJson).toList());

  Future<void> save({
    required String userId,
    required String familyId,
    required double latitude,
    required double longitude,
    required DateTime parkedAt,
  }) => _client.from('parked_cars').upsert({
    'user_id': userId,
    'family_id': familyId,
    'lat': latitude,
    'lng': longitude,
    'parked_at': parkedAt.toUtc().toIso8601String(),
  }, onConflict: 'user_id,family_id');

  Future<void> remove({required String userId, required String familyId}) async {
    final deleted = await _client
        .from('parked_cars')
        .delete()
        .eq('user_id', userId)
        .eq('family_id', familyId)
        .select('user_id');
    if (deleted.isEmpty) {
      throw const PostgrestException(message: 'De parkeerplek kon niet worden verwijderd.');
    }
  }
}
