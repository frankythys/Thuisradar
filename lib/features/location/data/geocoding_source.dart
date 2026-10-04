import 'package:geocoding/geocoding.dart';

import '../domain/place_address.dart';

/// Reverse geocoding via de native geocoder van het toestel (Android Geocoder /
/// iOS CLGeocoder). Gratis, geen API-sleutel. Resultaten worden in het geheugen
/// bewaard per adresraster, zodat we niet blijven hercoderen bij elke update.
class GeocodingSource {
  final _cache = <(double, double), PlaceAddress>{};
  final _misses = <(double, double)>{};

  /// Straat + gemeente voor een coördinaat, of null als het niet lukt.
  /// Faalt stil: reverse geocoding is een verrijking, geen voorwaarde.
  Future<PlaceAddress?> addressFor(double latitude, double longitude) async {
    final key = snapToAddressGrid(latitude, longitude);
    final cached = _cache[key];
    if (cached != null) return cached;
    if (_misses.contains(key)) return null;

    try {
      final marks = await Geocoding().placemarkFromCoordinates(key.$1, key.$2);
      if (marks.isEmpty) {
        _misses.add(key);
        return null;
      }
      final address = _toAddress(marks.first);
      if (address.isEmpty) {
        _misses.add(key);
        return null;
      }
      _cache[key] = address;
      return address;
    } catch (_) {
      _misses.add(key);
      return null;
    }
  }

  PlaceAddress _toAddress(Placemark mark) => PlaceAddress(
    street: _first([mark.street, mark.thoroughfare]),
    municipality: _first([mark.locality, mark.subAdministrativeArea, mark.administrativeArea]),
  );

  String? _first(List<String?> values) {
    for (final value in values) {
      final trimmed = value?.trim();
      if (trimmed != null && trimmed.isNotEmpty) return trimmed;
    }
    return null;
  }
}
