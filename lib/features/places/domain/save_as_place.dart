import '../../location/domain/member_location.dart';
import '../../location/domain/trip_status.dart';
import 'place.dart';
import 'place_timeline.dart';

/// Mag het persoonsscherm "Deze plek opslaan" aanbieden? Enkel als het lid
/// een verse locatie heeft, niet onderweg is en nog in geen enkele opgeslagen
/// plaats staat.
bool canSaveAsPlace(MemberLocation? location, List<Place> places, DateTime now) {
  if (location == null) return false;
  final state = TripStatus.at(location, now).state;
  if (state == TripState.moving || state == TripState.stale || state == TripState.missing) return false;
  return placeNameAt(places, location.latitude, location.longitude) == null;
}
