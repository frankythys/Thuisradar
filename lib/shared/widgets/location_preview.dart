import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/theme/app_colors.dart';
import 'app_map_tiles.dart';

/// Werkelijke kaartpositie, gedeeld door detail, chat en het SOS-scherm.
class LocationPreview extends StatelessWidget {
  const LocationPreview({
    super.key,
    required this.latitude,
    required this.longitude,
    this.initial = '•',
    this.route = const [],
    this.segments = const [],
    this.height = 220,
    this.fitBounds = false,
    this.showMarker = true,
  });
  final double latitude, longitude, height;
  final String initial;
  final List<LatLng> route;

  /// Route in aaneengesloten stukken. Gaten tussen de metingen worden niet
  /// verbonden, zodat er nooit een rechte lijn door de stad loopt.
  final List<List<LatLng>> segments;

  /// Zoom de kaart op de volledige route in plaats van op één punt.
  final bool fitBounds;

  /// Toon de avatar-marker. Uit bij routekaarten: daar vertelt de route zelf
  /// het verhaal en tonen we alleen een begin- en een eindpunt.
  final bool showMarker;

  @override
  Widget build(BuildContext context) {
    final lines = segments.isNotEmpty ? segments : [if (route.length > 1) route];
    final points = [for (final line in lines) ...line];
    return ClipRRect(
      borderRadius: BorderRadius.circular(18),
      child: SizedBox(
        height: height,
        child: FlutterMap(
          options: MapOptions(
            initialCenter: LatLng(latitude, longitude),
            initialZoom: 14,
            initialCameraFit: fitBounds && points.length > 1
                ? CameraFit.coordinates(coordinates: points, padding: const EdgeInsets.all(16))
                : null,
            interactionOptions: const InteractionOptions(flags: InteractiveFlag.none),
          ),
          children: [
            const AppMapTiles(),
            if (lines.isNotEmpty)
              PolylineLayer(
                polylines: [
                  for (final line in lines) Polyline(points: line, color: AppColors.primary, strokeWidth: 4),
                ],
              ),
            if (showMarker)
              MarkerLayer(
                markers: [
                  Marker(
                    point: LatLng(latitude, longitude),
                    width: 48,
                    height: 48,
                    child: Container(
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: AppColors.primary,
                        border: Border.all(color: Colors.white, width: 4),
                      ),
                      child: Text(
                        initial,
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w800,
                          fontSize: 20,
                        ),
                      ),
                    ),
                  ),
                ],
              )
            else if (points.length > 1)
              MarkerLayer(
                markers: [
                  _routePoint(point: points.first, color: AppColors.muted, size: 14),
                  _routePoint(point: points.last, color: AppColors.primary, size: 18),
                ],
              ),
            // Verplichte naamsvermelding van de gratis OpenStreetMap-tegels.
            // Klein en zonder kader, zodat de kaart zelf rustig blijft.
            Align(
              alignment: Alignment.bottomRight,
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () => launchUrl(Uri.https('www.openstreetmap.org', '/copyright')),
                child: const Padding(
                  padding: EdgeInsets.fromLTRB(8, 4, 6, 4),
                  child: Text(
                    '© OpenStreetMap-bijdragers',
                    style: TextStyle(fontSize: 9, color: AppColors.muted),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Begin- en eindpunt van een route: klein rondje met witte rand.
Marker _routePoint({required LatLng point, required Color color, required double size}) => Marker(
  point: point,
  width: size,
  height: size,
  child: DecoratedBox(
    decoration: BoxDecoration(
      shape: BoxShape.circle,
      color: color,
      border: Border.all(color: Colors.white, width: 3),
    ),
  ),
);

Future<void> openDirections(BuildContext context, double latitude, double longitude) async {
  final uri = Uri.https('www.google.com', '/maps/dir/', {'api': '1', 'destination': '$latitude,$longitude'});
  try {
    if (await launchUrl(uri, mode: LaunchMode.externalApplication)) return;
  } on Exception {
    /* Toon een herstelbare fout in de app. */
  }
  if (context.mounted) {
    ScaffoldMessenger.of(context)
        .showSnackBar(const SnackBar(content: Text('Route-app openen mislukt. Probeer opnieuw.')));
  }
}
