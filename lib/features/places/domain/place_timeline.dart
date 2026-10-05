import '../../../core/utils/geo.dart';
import '../../location/domain/timeline.dart';
import 'place.dart';

/// Geeft stops in de tijdlijn een plaatsnaam als hun middelpunt binnen de straal
/// van een plaats ligt. Puur; vervangt het `placeName`-veld dat Fase C open liet.
List<TimelineEntry> attachPlaceNames(List<TimelineEntry> entries, List<Place> places) {
  if (places.isEmpty) return entries;
  return [
    for (final entry in entries)
      if (entry.kind == TimelineKind.stop) _withPlace(entry, places) else entry,
  ];
}

/// Naam van de eigen plaats waar het punt in ligt, of null als het nergens in valt.
String? placeNameAt(List<Place> places, double latitude, double longitude) {
  for (final place in places) {
    final distance = distanceMeters(latitude, longitude, place.latitude, place.longitude);
    if (distance <= place.radiusMeters) return place.name;
  }
  return null;
}

TimelineEntry _withPlace(TimelineEntry entry, List<Place> places) {
  final name = placeNameAt(places, entry.latitude, entry.longitude);
  if (name == null) return entry;
  return TimelineEntry(
    kind: entry.kind,
    start: entry.start,
    end: entry.end,
    latitude: entry.latitude,
    longitude: entry.longitude,
    distanceMeters: entry.distanceMeters,
    placeName: name,
  );
}
