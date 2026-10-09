import '../../places/domain/place.dart';

/// Eén zone zoals ze bij Android geregistreerd wordt.
///
/// De id bevat de plaats én haar ligging en straal. Verschuift een plaats, dan
/// verandert de id: de oude zone gaat weg en de nieuwe komt erbij. Zo volstaat
/// het om id's te vergelijken bij het opnieuw registreren.
class GeofenceZone {
  const GeofenceZone({
    required this.placeId,
    required this.latitude,
    required this.longitude,
    required this.radiusMeters,
  });

  /// Android raadt minstens 100 m aan. Kleiner geeft gemiste of late meldingen.
  /// Mag groter zijn dan de straal van de plaats: de server ziet iemand pas als
  /// "buiten" voorbij straal + 50 m, en een plaats is altijd minstens 50 m.
  static const minRadiusMeters = 100.0;

  static const _prefix = 'tr1';

  factory GeofenceZone.fromPlace(Place place) => GeofenceZone(
    placeId: place.id,
    latitude: place.latitude,
    longitude: place.longitude,
    radiusMeters: place.radiusMeters < minRadiusMeters ? minRadiusMeters : place.radiusMeters.toDouble(),
  );

  final String placeId;
  final double latitude;
  final double longitude;
  final double radiusMeters;

  String get id =>
      '$_prefix|$placeId|${latitude.toStringAsFixed(5)}|${longitude.toStringAsFixed(5)}|${radiusMeters.round()}';

  /// Is deze id van ons (en niet van een andere bibliotheek)?
  static bool isOurs(String id) => id.startsWith('$_prefix|');

  /// De plaats-id uit een zone-id, of null als het geen zone van ons is.
  static String? placeIdOf(String id) {
    final parts = id.split('|');
    if (parts.length != 5 || parts.first != _prefix || parts[1].isEmpty) return null;
    return parts[1];
  }
}

/// Wat er moet gebeuren om de geregistreerde zones gelijk te zetten met de
/// plaatsen van het gezin.
class GeofenceSyncPlan {
  const GeofenceSyncPlan({required this.toRemove, required this.toAdd});

  final List<String> toRemove;
  final List<GeofenceZone> toAdd;

  bool get isEmpty => toRemove.isEmpty && toAdd.isEmpty;
}

/// Vergelijkt de geregistreerde zone-id's met de gewenste plaatsen. Zones van
/// andere bibliotheken blijven ongemoeid.
GeofenceSyncPlan planGeofenceSync({required Iterable<String> registeredIds, required List<Place> places}) {
  final desired = {
    for (final place in places) GeofenceZone.fromPlace(place).id: GeofenceZone.fromPlace(place),
  };
  final ours = registeredIds.where(GeofenceZone.isOurs).toSet();
  return GeofenceSyncPlan(
    toRemove: [
      for (final id in ours)
        if (!desired.containsKey(id)) id,
    ],
    toAdd: [
      for (final entry in desired.entries)
        if (!ours.contains(entry.key)) entry.value,
    ],
  );
}
