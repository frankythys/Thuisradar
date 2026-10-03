import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/supabase/supabase_providers.dart';
import '../data/places_repository.dart';
import '../domain/place.dart';
import '../domain/place_presence.dart';
import '../domain/place_status.dart';

final placesRepositoryProvider = Provider<PlacesRepository>(
  (ref) => PlacesRepository(ref.watch(supabaseClientProvider)),
);

final familyPlacesProvider = StreamProvider.family<List<Place>, String>(
  (ref, familyId) => ref.watch(placesRepositoryProvider).watchPlaces(familyId),
);

final familyPresenceProvider = StreamProvider.family<List<PlacePresence>, String>(
  (ref, familyId) => ref.watch(placesRepositoryProvider).watchPresence(familyId),
);

/// Per gebruiker: waar die nu is (plaatsnaam + sinds), voor de ledenlijst.
final currentPlaceByUserProvider = Provider.family<Map<String, PlaceStatus>, String>((ref, familyId) {
  final places = ref.watch(familyPlacesProvider(familyId)).value ?? const [];
  final presence = ref.watch(familyPresenceProvider(familyId)).value ?? const [];
  return currentPlaceByUser(places, presence);
});
