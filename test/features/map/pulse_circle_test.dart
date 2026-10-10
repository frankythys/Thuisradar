import 'package:flutter_test/flutter_test.dart';
import 'package:thuisradar/features/map/domain/pulse_circle.dart';

void main() {
  test('rondje recht op het punt: cirkel op het punt, straal in meters volgens zoom', () {
    final at17 = pulseCircle(latitude: 51, longitude: 4, dxPx: 0, dyPx: 0, radiusPx: 40, zoom: 17);
    final at18 = pulseCircle(latitude: 51, longitude: 4, dxPx: 0, dyPx: 0, radiusPx: 40, zoom: 18);
    expect(at17.latitude, 51);
    expect(at17.longitude, 4);
    // Eén zoomstap verder = half zoveel meter per punt.
    expect(at18.radiusMeters, closeTo(at17.radiusMeters / 2, 1e-9));
    // Op zoom 17 in België: ongeveer 0,75 m per punt.
    expect(at17.radiusMeters, closeTo(40 * 0.75, 1.5));
  });

  test('stilstaand lid: rondje hangt boven het punt, dus cirkel noordelijker', () {
    final circle = pulseCircle(latitude: 51, longitude: 4, dxPx: 0, dyPx: -58, radiusPx: 38, zoom: 17);
    expect(circle.latitude, greaterThan(51));
    expect(circle.longitude, 4);
  });

  test('puls: begint klein en duidelijk, eindigt groot en onzichtbaar', () {
    expect(pulseLook(0), (growPx: 4.0, opacity: 0.35));
    expect(pulseLook(1).growPx, 18);
    expect(pulseLook(1).opacity, 0);
  });
}
