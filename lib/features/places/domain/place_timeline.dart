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

TimelineEntry _withPlace(TimelineEntry entry, List<Place> places) {
  for (final place in places) {
    final distance = distanceMeters(entry.latitude, entry.longitude, place.latitude, place.longitude);
    if (distance <= place.radiusMeters) {
      return TimelineEntry(
        kind: entry.kind,
        start: entry.start,
        end: entry.end,
        latitude: entry.latitude,
        longitude: entry.longitude,
        distanceMeters: entry.distanceMeters,
        placeName: place.name,
      );
    }
  }
  return entry;
}
