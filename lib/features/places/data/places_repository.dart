import 'package:supabase_flutter/supabase_flutter.dart';

import '../domain/place.dart';
import '../domain/place_presence.dart';

class PlacesRepository {
  PlacesRepository(this._client);

  final SupabaseClient _client;

  Stream<List<Place>> watchPlaces(String familyId) {
    return _client
        .from('places')
        .stream(primaryKey: ['id'])
        .eq('family_id', familyId)
        .map((rows) => rows.map(Place.fromJson).toList());
  }

  Future<void> create({
    required String familyId,
    required String name,
    required double latitude,
    required double longitude,
    required int radiusMeters,
    required String icon,
  }) {
    return _client.from('places').insert({
      'family_id': familyId,
      'name': name,
      'lat': latitude,
      'lng': longitude,
      'radius_m': radiusMeters,
      'icon': icon,
    });
  }

  Future<void> delete(String id) {
    return _client.from('places').delete().eq('id', id);
  }

  /// Realtime aanwezigheid (enkel wie momenteel binnen is).
  Stream<List<PlacePresence>> watchPresence(String familyId) {
    return _client
        .from('place_presence')
        .stream(primaryKey: ['user_id', 'place_id'])
        .eq('family_id', familyId)
        .map((rows) => rows.map(PlacePresence.fromJson).where((p) => p.isInside).toList());
  }
}
