import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:thuisradar/features/map/domain/driving_follow.dart';
import 'package:thuisradar/features/map/domain/google_camera.dart';

void main() {
  test('rijrichting volgt de weg en negeert GPS-schommelingen', () {
    expect(drivingBearing(const LatLng(51, 3), const LatLng(51, 3.000001)), isNull);
    expect(drivingBearing(const LatLng(51, 3), const LatLng(51.001, 3)), closeTo(0, .01));
    expect(drivingBearing(const LatLng(51, 3), const LatLng(51, 3.001)), closeTo(90, .01));
  });
  test('draaien kiest de korte weg over noord', () {
    expect(interpolateBearing(350, 10, .5), closeTo(0, .001));
    expect(interpolateBearing(10, 350, .5), closeTo(0, .001));
  });
  test('volgcamera kijkt vooruit in de rijrichting en past afstand aan zoom aan', () {
    const point = LatLng(51, 3);
    final north = drivingCameraCenter(point, 0, 16, 800, 100);
    final east = drivingCameraCenter(point, 90, 16, 800, 100);
    final zoomed = drivingCameraCenter(point, 0, 20, 800, 100);
    expect(north.latitude, greaterThan(point.latitude));
    expect(east.longitude, greaterThan(point.longitude));
    expect(zoomed.latitude - point.latitude, lessThan(north.latitude - point.latitude));
  });
  test('Google-padding volgt de rotatie zodat tikvlakken op de markers blijven', () {
    final east = googleCameraTarget(latitude: 51, longitude: 3, zoom: 16, bottomPadding: 300, bearing: 90);
    final south = googleCameraTarget(latitude: 51, longitude: 3, zoom: 16, bottomPadding: 300, bearing: 180);
    expect(east.latitude, closeTo(51, .000001));
    expect(east.longitude, greaterThan(3));
    expect(south.latitude, lessThan(51));
    expect(south.longitude, closeTo(3, .000001));
  });
}
