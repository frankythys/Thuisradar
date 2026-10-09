import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/theme/app_colors.dart';
import 'app_map_tiles.dart';

/// Werkelijke kaartpositie, gedeeld door detail, chat en het SOS-scherm.
class LocationPreview extends StatefulWidget {
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
    this.allowFullscreen = false,
    this.interactive = false,
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
  final bool allowFullscreen;
  final bool interactive;

  @override
  State<LocationPreview> createState() => _LocationPreviewState();
}

class _LocationPreviewState extends State<LocationPreview> {
  final _controller = MapController();
  bool _ready = false;
  bool _fitScheduled = false;

  List<List<LatLng>> get _lines => widget.segments.isNotEmpty
      ? widget.segments
      : [if (widget.route.length > 1) widget.route];

  List<LatLng> get _points => [for (final line in _lines) ...line];

  @override
  void didUpdateWidget(covariant LocationPreview oldWidget) {
    super.didUpdateWidget(oldWidget);
    final oldPoints = [
      for (final line
          in oldWidget.segments.isNotEmpty
              ? oldWidget.segments
              : [oldWidget.route])
        ...line,
    ];
    final points = _points;
    final changed =
        oldPoints.length != points.length ||
        List.generate(
          points.length,
          (i) => i,
        ).any((i) => oldPoints[i] != points[i]);
    if (changed ||
        widget.fitBounds != oldWidget.fitBounds ||
        widget.latitude != oldWidget.latitude ||
        widget.longitude != oldWidget.longitude) {
      _scheduleFit();
    }
  }

  void _scheduleFit() {
    if (_fitScheduled || !_ready) return;
    _fitScheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _fitScheduled = false;
      if (!mounted || !_ready) return;
      final points = _points;
      if (widget.fitBounds && points.length > 1) {
        _controller.fitCamera(
          CameraFit.coordinates(
            coordinates: points,
            padding: const EdgeInsets.all(28),
            maxZoom: 17,
          ),
        );
      } else {
        _controller.move(
          widget.fitBounds && points.isNotEmpty
              ? points.first
              : LatLng(widget.latitude, widget.longitude),
          14,
        );
      }
    });
  }

  void _fullscreen() {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => Scaffold(
          appBar: AppBar(title: const Text('Ritkaart')),
          body: Padding(
            padding: const EdgeInsets.all(12),
            child: SizedBox.expand(
              child: LocationPreview(
                latitude: widget.latitude,
                longitude: widget.longitude,
                initial: widget.initial,
                segments: _lines,
                height: double.infinity,
                fitBounds: true,
                showMarker: widget.showMarker,
                interactive: true,
              ),
            ),
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final lines = _lines;
    final points = [for (final line in lines) ...line];
    return ClipRRect(
      borderRadius: BorderRadius.circular(18),
      child: SizedBox(
        height: widget.height,
        child: FlutterMap(
          mapController: _controller,
          options: MapOptions(
            initialCenter: LatLng(widget.latitude, widget.longitude),
            initialZoom: 14,
            initialCameraFit: widget.fitBounds && points.length > 1
                ? CameraFit.coordinates(
                    coordinates: points,
                    padding: const EdgeInsets.all(28),
                    maxZoom: 17,
                  )
                : null,
            onMapReady: () {
              _ready = true;
              if (widget.fitBounds) _scheduleFit();
            },
            interactionOptions: InteractionOptions(
              flags: widget.interactive
                  ? InteractiveFlag.all & ~InteractiveFlag.rotate
                  : InteractiveFlag.none,
            ),
          ),
          children: [
            const AppMapTiles(),
            if (lines.isNotEmpty)
              PolylineLayer(
                polylines: [
                  for (final line in lines.where((line) => line.length > 1))
                    Polyline(
                      points: line,
                      color: AppColors.primary,
                      strokeWidth: 4,
                    ),
                ],
              ),
            if (!widget.showMarker && lines.any((line) => line.length == 1))
              MarkerLayer(
                markers: [
                  for (final line in lines)
                    if (line.length == 1)
                      _routePoint(
                        point: line.single,
                        color: AppColors.muted,
                        size: 10,
                      ),
                ],
              ),
            if (widget.showMarker)
              MarkerLayer(
                markers: [
                  Marker(
                    point: LatLng(widget.latitude, widget.longitude),
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
                        widget.initial,
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
                  _routePoint(
                    point: points.first,
                    color: AppColors.muted,
                    size: 14,
                  ),
                  _routePoint(
                    point: points.last,
                    color: AppColors.primary,
                    size: 18,
                  ),
                ],
              ),
            // Verplichte naamsvermelding van de gratis OpenStreetMap-tegels.
            // Klein en zonder kader, zodat de kaart zelf rustig blijft.
            Align(
              alignment: Alignment.bottomRight,
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () =>
                    launchUrl(Uri.https('www.openstreetmap.org', '/copyright')),
                child: const Padding(
                  padding: EdgeInsets.fromLTRB(8, 4, 6, 4),
                  child: Text(
                    '© OpenStreetMap-bijdragers',
                    style: TextStyle(fontSize: 9, color: AppColors.muted),
                  ),
                ),
              ),
            ),
            if (widget.allowFullscreen)
              Align(
                alignment: Alignment.topRight,
                child: Padding(
                  padding: const EdgeInsets.all(8),
                  child: Material(
                    color: Colors.white,
                    elevation: 2,
                    borderRadius: BorderRadius.circular(12),
                    child: IconButton(
                      tooltip: 'Ritkaart vergroten',
                      onPressed: _fullscreen,
                      icon: const Icon(
                        Icons.fullscreen,
                        color: AppColors.primary,
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
}

/// Begin- en eindpunt van een route: klein rondje met witte rand.
Marker _routePoint({
  required LatLng point,
  required Color color,
  required double size,
}) => Marker(
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
