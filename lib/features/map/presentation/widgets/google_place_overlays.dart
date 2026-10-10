import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart' as gm;

import '../../../places/domain/place.dart';

/// Plaatsen (cirkel + icoon) rechtstreeks in Google Maps, zodat ze vast aan de
/// kaart zitten en niet meeglijden tijdens het scrollen.

/// Zelfde uitzicht als de cirkels op de OpenStreetMap-kaart. Google rekent de
/// randdikte in schermpixels, vandaar [pixelRatio].
Set<gm.Circle> placeCircles(List<Place> places, {required Color color, required double pixelRatio}) => {
  for (final place in places)
    gm.Circle(
      circleId: gm.CircleId(place.id),
      center: gm.LatLng(place.latitude, place.longitude),
      radius: place.radiusMeters.toDouble(),
      fillColor: color.withValues(alpha: 0.08),
      strokeColor: color.withValues(alpha: 0.5),
      strokeWidth: (1.5 * pixelRatio).round(),
    ),
};

/// Eén marker per plaats, gecentreerd op het middelpunt. Plaatsen waarvan het
/// icoon nog niet getekend is, worden even overgeslagen.
Set<gm.Marker> placeMarkers(List<Place> places, Map<String, gm.BitmapDescriptor> icons) => {
  for (final place in places)
    if (icons[place.icon] case final icon?)
      gm.Marker(
        markerId: gm.MarkerId('place_${place.id}'),
        position: gm.LatLng(place.latitude, place.longitude),
        icon: icon,
        anchor: const Offset(0.5, 0.5),
      ),
};

/// Tekent een Material-icoon als PNG, scherp op dit scherm.
Future<gm.BitmapDescriptor> placeIconBitmap(
  IconData icon, {
  required Color color,
  required double size,
  required double pixelRatio,
}) async {
  final painter = TextPainter(
    textDirection: TextDirection.ltr,
    text: TextSpan(
      text: String.fromCharCode(icon.codePoint),
      style: TextStyle(
        fontSize: size * pixelRatio,
        fontFamily: icon.fontFamily,
        package: icon.fontPackage,
        color: color,
        height: 1,
      ),
    ),
  )..layout();
  final pixels = (size * pixelRatio).ceil();
  final recorder = ui.PictureRecorder();
  painter.paint(Canvas(recorder), Offset((pixels - painter.width) / 2, (pixels - painter.height) / 2));
  painter.dispose();
  final image = await recorder.endRecording().toImage(pixels, pixels);
  final data = await image.toByteData(format: ui.ImageByteFormat.png);
  image.dispose();
  return gm.BitmapDescriptor.bytes(Uint8List.view(data!.buffer), width: size, height: size);
}
