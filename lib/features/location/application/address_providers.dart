import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/geocoding_source.dart';
import '../domain/place_address.dart';

final geocodingSourceProvider = Provider<GeocodingSource>((ref) => GeocodingSource());

/// Adres (straat + gemeente) voor een locatie. Key = afgeronde coördinaten op
/// het adresraster, zodat dezelfde buurt de aanvraag deelt en hergebruikt.
/// `autoDispose` zodat een oude buurt geen provider blijft vasthouden; de
/// bron zelf cachet het resultaat wel.
final placeAddressProvider = FutureProvider.autoDispose.family<PlaceAddress?, (double, double)>(
  (ref, coordinates) async {
    return ref.watch(geocodingSourceProvider).addressFor(coordinates.$1, coordinates.$2);
  },
);
