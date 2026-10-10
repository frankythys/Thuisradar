import 'dart:math' as math;

/// Rekent de lichtkring rond een geselecteerd rondje om naar een cirkel in
/// meters op de kaart (Google Maps tekent cirkels in meters, niet in pixels).
///
/// [dxPx]/[dyPx]: waar het midden van het rondje ligt t.o.v. het kaartpunt,
/// in schermpunten (dy positief = naar onder). [radiusPx]: straal in punten.
/// Web Mercator met tegels van 256 punten, zoals Google en flutter_map.
({double latitude, double longitude, double radiusMeters}) pulseCircle({
  required double latitude,
  required double longitude,
  required double dxPx,
  required double dyPx,
  required double radiusPx,
  required double zoom,
}) {
  final cosLat = math.cos(latitude * math.pi / 180);
  final metersPerPx = 156543.03392 * cosLat / math.pow(2, zoom);
  return (
    latitude: latitude - dyPx * metersPerPx / 111320,
    longitude: longitude + dxPx * metersPerPx / (111320 * cosLat),
    radiusMeters: radiusPx * metersPerPx,
  );
}

/// Grootte en doorzichtigheid van de lichtkring op fase 0..1: dijt uit van
/// 4 tot 18 punten buiten het rondje en vervaagt.
({double growPx, double opacity}) pulseLook(double phase) =>
    (growPx: 4 + 14 * phase, opacity: 0.35 * (1 - phase));
