import '../../notifications/domain/family_event.dart';
import '../../places/domain/place.dart';
import '../../places/domain/place_presence.dart';

/// Eén plaats in het plaatsenblok van de ledenlijst.
class PlaceOverview {
  const PlaceOverview({required this.place, required this.presentCount, this.since, this.lastArrival});

  final Place place;

  /// Aantal gezinsleden dat er nu is.
  final int presentCount;

  /// Sinds wanneer het eerste aanwezige lid er is ("Sinds 13:03").
  final DateTime? since;

  /// Laatste aankomst van een gezinslid in deze zone.
  final DateTime? lastArrival;

  bool get hasPeople => presentCount > 0;
}

/// De belangrijkste plaatsen voor de ledenlijst: eerst de zones waar nu iemand
/// is, dan de drukst bezochte zones (aankomsten uit `family_events`), dan
/// alfabetisch. Puur en testbaar, zonder Flutter of Supabase.
List<PlaceOverview> placeOverviews(
  List<Place> places,
  List<PlacePresence> presence,
  List<FamilyEvent> events, {
  int limit = 3,
}) {
  final arrivals = <String, int>{};
  final lastArrival = <String, DateTime>{};
  for (final event in events) {
    if (event.type != FamilyEventType.arrival) continue;
    final placeId = event.placeId;
    if (placeId == null) continue;
    arrivals[placeId] = (arrivals[placeId] ?? 0) + 1;
    final current = lastArrival[placeId];
    if (current == null || event.createdAt.isAfter(current)) {
      lastArrival[placeId] = event.createdAt;
    }
  }

  final overviews = [
    for (final place in places)
      PlaceOverview(
        place: place,
        presentCount: presence.where((p) => p.placeId == place.id && p.isInside).length,
        since: _earliestSince(presence, place.id),
        lastArrival: lastArrival[place.id],
      ),
  ];

  overviews.sort((a, b) {
    if (a.hasPeople != b.hasPeople) return a.hasPeople ? -1 : 1;
    final visits = (arrivals[b.place.id] ?? 0).compareTo(arrivals[a.place.id] ?? 0);
    if (visits != 0) return visits;
    return a.place.name.toLowerCase().compareTo(b.place.name.toLowerCase());
  });

  return limit <= 0 ? overviews : overviews.take(limit).toList();
}

/// Vroegste `since` van de leden die nu binnen deze zone zijn.
DateTime? _earliestSince(List<PlacePresence> presence, String placeId) {
  DateTime? earliest;
  for (final entry in presence) {
    if (entry.placeId != placeId || !entry.isInside) continue;
    final since = entry.since;
    if (since == null) continue;
    if (earliest == null || since.isBefore(earliest)) earliest = since;
  }
  return earliest;
}
