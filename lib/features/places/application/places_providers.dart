import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/supabase/supabase_providers.dart';
import '../../../core/utils/resilient_stream.dart';
import '../../../core/utils/resync_signal.dart';
import '../../location/application/location_providers.dart';
import '../data/places_repository.dart';
import '../domain/confirmed_presence.dart';
import '../domain/place.dart';
import '../domain/place_presence.dart';
import '../domain/place_status.dart';

final placesRepositoryProvider = Provider<PlacesRepository>(
  (ref) => PlacesRepository(ref.watch(supabaseClientProvider)),
);

final familyPlacesProvider = StreamProvider.family<List<Place>, String>(
  (ref, familyId) => ref.watch(placesRepositoryProvider).watchPlaces(familyId),
);

/// Realtime aanwezigheid; herstelt zichzelf net als de locatiestroom, zodat
/// "Thuis" niet blijft hangen op een oude stand.
final familyPresenceProvider = StreamProvider.family<List<PlacePresence>, String>((ref, familyId) {
  final repository = ref.watch(placesRepositoryProvider);
  return resilientStream(
    () => repository.watchPresence(familyId),
    resync: ref.watch(resyncSignalProvider).stream,
    onError: (error) => debugPrint('Aanwezigheidsstroom (realtime) fout: $error'),
  );
});

/// Per gebruiker: waar die nu is (plaatsnaam + sinds), voor de ledenlijst.
final currentPlaceByUserProvider = Provider.family<Map<String, PlaceStatus>, String>((ref, familyId) {
  final places = ref.watch(familyPlacesProvider(familyId)).value ?? const [];
  final presence = ref.watch(familyPresenceProvider(familyId)).value ?? const [];
  final locations = ref.watch(familyLocationsProvider(familyId)).value ?? const [];
  return currentPlaceByUser(places, confirmedPresence(presence, places, locations));
});
