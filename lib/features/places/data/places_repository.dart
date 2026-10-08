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
    String? address,
    List<String>? watchedMembers,
    bool notifyArrival = true,
    bool notifyDeparture = true,
  }) {
    return _client.from('places').insert({
      'family_id': familyId,
      'name': name,
      'lat': latitude,
      'lng': longitude,
      'radius_m': radiusMeters,
      'icon': icon,
      'address': address,
      'watched_members': watchedMembers,
      'notify_arrival': notifyArrival,
      'notify_departure': notifyDeparture,
    });
  }

  Future<void> delete(String id) async {
    final deleted = await _client.from('places').delete().eq('id', id).select('id');
    if (deleted.isEmpty) {
      throw const PostgrestException(
        message: 'De plaats kon niet worden verwijderd. Controleer je gezinslidmaatschap en probeer opnieuw.',
        code: 'place_delete_not_confirmed',
      );
    }
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
