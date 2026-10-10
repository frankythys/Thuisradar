import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:thuisradar/features/map/domain/google_camera.dart';

/// Afstand in schermpunten tussen twee breedtegraden bij een zoomniveau.
double _pixelsBetween(double fromLat, double toLat, double zoom) {
  double y(double lat) {
    final s = math.sin(lat * math.pi / 180);
    return (0.5 - math.log((1 + s) / (1 - s)) / (4 * math.pi)) * 256 * math.pow(2, zoom);
  }

  return y(fromLat) - y(toLat);
}

void main() {
  test('zonder onderpaneel: zelfde middelpunt als de kaart erboven', () {
    final target = googleCameraTarget(latitude: 51.0, longitude: 4.0, zoom: 14);
    expect(target.latitude, 51.0);
    expect(target.longitude, 4.0);
  });

  test('onderpaneel van 300 punten: Google-doel 150 punten noordelijker, Thuis blijft op dezelfde plek', () {
    final target = googleCameraTarget(latitude: 51.0, longitude: 4.0, zoom: 14, bottomPadding: 300);
    expect(target.longitude, 4.0);
    expect(target.latitude, greaterThan(51.0));
    expect(_pixelsBetween(51.0, target.latitude, 14), closeTo(150, 0.01));
  });

  test('ingezoomd verschuift het doel minder graden', () {
    final far = googleCameraTarget(latitude: 51.0, longitude: 4.0, zoom: 8, bottomPadding: 300);
    final close = googleCameraTarget(latitude: 51.0, longitude: 4.0, zoom: 16, bottomPadding: 300);
    expect(far.latitude - 51.0, greaterThan(close.latitude - 51.0));
  });

  test('enkel een echte camerabeweging verplaatst de Google-kaart', () {
    const here = (latitude: 51.0, longitude: 4.0, zoom: 12.0);
    expect(googleCameraChanged(null, here), isTrue);
    expect(googleCameraChanged(here, here), isFalse);
    expect(googleCameraChanged(here, (latitude: 51.001, longitude: 4.0, zoom: 12.0)), isTrue);
    expect(googleCameraChanged(here, (latitude: 51.0, longitude: 4.0, zoom: 12.5)), isTrue);
  });
}
