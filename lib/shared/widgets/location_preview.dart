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
    this.height = 220,
  });
  final double latitude, longitude, height;
  final String initial;
  final List<LatLng> route;

  @override
  Widget build(BuildContext context) => ClipRRect(
    borderRadius: BorderRadius.circular(18),
    child: SizedBox(
      height: height,
      child: FlutterMap(
        options: MapOptions(
          initialCenter: LatLng(latitude, longitude),
          initialZoom: 14,
          interactionOptions: const InteractionOptions(
            flags: InteractiveFlag.none,
          ),
        ),
        children: [
          const AppMapTiles(),
          if (route.length > 1)
            PolylineLayer(
              polylines: [
                Polyline(
                  points: route,
                  color: AppColors.primary,
                  strokeWidth: 4,
                ),
              ],
            ),
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
          ),
          Align(
            alignment: Alignment.bottomRight,
            child: Material(
              color: const Color(0xEFFFFFFF),
              child: InkWell(
                onTap: () =>
                    launchUrl(Uri.https('www.openstreetmap.org', '/copyright')),
                child: const Padding(
                  padding: EdgeInsets.all(4),
                  child: Text(
                    '© OpenStreetMap-bijdragers',
                    style: TextStyle(fontSize: 10, color: AppColors.muted),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    ),
  );
}

Future<void> openDirections(
  BuildContext context,
  double latitude,
  double longitude,
) async {
  final uri = Uri.https('www.google.com', '/maps/dir/', {
    'api': '1',
    'destination': '$latitude,$longitude',
  });
  try {
    if (await launchUrl(uri, mode: LaunchMode.externalApplication)) return;
  } on Exception {
    /* Toon een herstelbare fout in de app. */
  }
  if (context.mounted) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Route-app openen mislukt. Probeer opnieuw.'),
      ),
    );
  }
}
