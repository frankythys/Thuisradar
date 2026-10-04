import 'package:latlong2/latlong.dart';

/// Only a successfully resolved address may be saved with its coordinates.
class SelectedPlaceLocation {
  SelectedPlaceLocation(this.center);
  LatLng center;
  String? address;
  int _revision = 0;

  int beginSearch() => ++_revision;
  void move(LatLng point, {required bool userGesture}) {
    center = point;
    if (userGesture) {
      address = null;
      _revision++;
    }
  }

  void editAddress() {
    address = null;
    _revision++;
  }

  bool resolve(int revision, LatLng point, String label) {
    if (revision != _revision) return false;
    center = point;
    address = label;
    return true;
  }
}
