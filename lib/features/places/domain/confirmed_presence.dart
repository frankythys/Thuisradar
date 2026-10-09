import '../../../core/utils/geo.dart';
import '../../location/domain/member_location.dart';
import 'place.dart';
import 'place_presence.dart';

/// Speling bovenop de straal: binnenshuis wijkt GPS vaak tientallen meters af.
const presenceToleranceMeters = 150.0;

/// Houdt enkel de aanwezigheden over die de laatste locatie niet tegenspreekt.
///
/// De opgeslagen aanwezigheid ("Franky is in Thuis") kan achterlopen, bv. bij
/// het opstarten of als een vertrek nog niet verwerkt is. Ligt de echte
/// GPS-positie duidelijk buiten de plaats, dan geloven we de GPS: anders zet
/// de kaart iemand die weg is nog even op Thuis, samen met de anderen.
/// Zonder bekende locatie blijft de aanwezigheid gewoon gelden.
List<PlacePresence> confirmedPresence(
  List<PlacePresence> presence,
  List<Place> places,
  List<MemberLocation> locations,
) {
  final placeById = {for (final p in places) p.id: p};
  final locationByUser = {for (final l in locations) l.userId: l};
  return [
    for (final pres in presence)
      if (_agrees(pres, placeById[pres.placeId], locationByUser[pres.userId])) pres,
  ];
}

bool _agrees(PlacePresence presence, Place? place, MemberLocation? location) {
  if (!presence.isInside || place == null || location == null) return true;
  final distance = distanceMeters(location.latitude, location.longitude, place.latitude, place.longitude);
  return distance <= place.radiusMeters + presenceToleranceMeters;
}
