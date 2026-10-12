import 'dart:math' as math;

import 'package:latlong2/latlong.dart';

/// Kleine GPS-schommelingen veranderen de rijrichting niet.
double? drivingBearing(LatLng from, LatLng to) {
  const distance = Distance();
  if (distance(from, to) < 5) return null;
  return (distance.bearing(from, to) + 360) % 360;
}

double interpolateBearing(double from, double to, double t) {
  final delta = (to - from + 540) % 360 - 180;
  return (from + delta * t + 360) % 360;
}

/// Auto op 65% van de vrije kaarthoogte, met meer zicht vooruit.
LatLng drivingCameraCenter(LatLng point, double bearing, double zoom, double height, double bottomInset) {
  final pixels = (height - bottomInset).clamp(0, height) * .65 - height / 2;
  final metersPerPixel = 40075016.686 * math.cos(point.latitude * math.pi / 180) / (256 * math.pow(2, zoom));
  return const Distance().offset(point, pixels.abs() * metersPerPixel, pixels >= 0 ? bearing : bearing + 180);
}
