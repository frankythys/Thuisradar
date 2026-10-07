import '../../../core/utils/geo.dart';
import '../../location/domain/member_location.dart';

/// Waar een lid staat en sinds wanneer, voor "hier sinds 3 min" op de kaart
/// (ook buiten een opgeslagen plek, zoals Life360).
typedef StationaryAnchor = ({double lat, double lng, DateTime since});

/// Hoe ver mag een lid bewegen voor we een nieuwe stop beginnen te tellen?
const kStationaryMoveMeters = 60.0;

/// Werkt per lid bij sinds wanneer het op (ongeveer) dezelfde plek staat. Blijft
/// het binnen [moveThresholdMeters] van zijn vorige punt, dan behouden we de
/// begintijd; verplaatst het verder, dan start de teller opnieuw vanaf de nieuwe
/// meting. Puur: geen Flutter of Supabase, zodat het te testen is.
Map<String, StationaryAnchor> updateStationaryAnchors(
  Map<String, StationaryAnchor> previous,
  List<MemberLocation> locations, {
  double moveThresholdMeters = kStationaryMoveMeters,
}) {
  final next = <String, StationaryAnchor>{};
  for (final loc in locations) {
    final prev = previous[loc.userId];
    if (prev != null &&
        distanceMeters(prev.lat, prev.lng, loc.latitude, loc.longitude) <= moveThresholdMeters) {
      next[loc.userId] = prev; // zelfde plek: behoud de begintijd
    } else {
      next[loc.userId] = (lat: loc.latitude, lng: loc.longitude, since: loc.updatedAt);
    }
  }
  return next;
}
