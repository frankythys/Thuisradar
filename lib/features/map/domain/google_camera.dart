import 'dart:math' as math;

/// Rekent de camera van de bovenliggende kaart (flutter_map) om naar de
/// Google-achtergrond eronder, zodat beide exact samenvallen.
///
/// Beide gebruiken Web Mercator met tegels van 256 punten, dus het zoomniveau
/// is identiek. Enkel bij een [bottomPadding] verschilt het middelpunt: Google
/// centreert dan in het vrije stuk boven de padding (waar het Google-logo
/// zichtbaar blijft boven het onderpaneel), dus schuiven we het doel even veel
/// naar boven.
({double latitude, double longitude}) googleCameraTarget({
  required double latitude,
  required double longitude,
  required double zoom,
  double bottomPadding = 0,
}) {
  if (bottomPadding == 0) return (latitude: latitude, longitude: longitude);
  final worldSize = 256 * math.pow(2, zoom);
  final y = _mercatorY(latitude) * worldSize - bottomPadding / 2;
  return (latitude: _latitudeAt(y / worldSize), longitude: longitude);
}

/// Is de camera genoeg veranderd om de Google-kaart te verplaatsen?
bool googleCameraChanged(
  ({double latitude, double longitude, double zoom})? previous,
  ({double latitude, double longitude, double zoom}) next,
) {
  if (previous == null) return true;
  const epsilon = 1e-7;
  return (previous.latitude - next.latitude).abs() > epsilon ||
      (previous.longitude - next.longitude).abs() > epsilon ||
      (previous.zoom - next.zoom).abs() > 1e-4;
}

/// 0 (noord) .. 1 (zuid), zoals de wereldkaart in Web Mercator.
double _mercatorY(double latitude) {
  final sinLat = math.sin(latitude * math.pi / 180).clamp(-0.9999, 0.9999);
  return 0.5 - math.log((1 + sinLat) / (1 - sinLat)) / (4 * math.pi);
}

double _latitudeAt(double mercatorY) {
  final n = math.pi * (1 - 2 * mercatorY);
  return 180 / math.pi * math.atan((math.exp(n) - math.exp(-n)) / 2);
}
