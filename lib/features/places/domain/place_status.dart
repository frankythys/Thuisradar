import 'place.dart';
import 'place_presence.dart';

/// Waar een lid nu is, voor de ledenlijst-status ("Thuis · sinds 17:42").
class PlaceStatus {
  const PlaceStatus({required this.name, required this.icon, this.since});

  final String name;
  final String icon;
  final DateTime? since;
}

/// Koppelt de huidige aanwezigheid aan plaatsnamen: per gebruiker de plaats
/// waar die nu is (als er meerdere zijn, de meest recente). Puur en testbaar.
Map<String, PlaceStatus> currentPlaceByUser(List<Place> places, List<PlacePresence> presence) {
  final byId = {for (final p in places) p.id: p};
  final result = <String, PlaceStatus>{};

  for (final pres in presence) {
    if (!pres.isInside) continue;
    final place = byId[pres.placeId];
    if (place == null) continue;

    final existing = result[pres.userId];
    final newer = existing?.since == null || (pres.since?.isAfter(existing!.since!) ?? false);
    if (existing == null || newer) {
      result[pres.userId] = PlaceStatus(name: place.name, icon: place.icon, since: pres.since);
    }
  }

  return result;
}
