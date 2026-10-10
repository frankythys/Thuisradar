import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart' as gm;
import 'package:latlong2/latlong.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../places/domain/place.dart';
import '../../../places/presentation/place_icons.dart';
import '../../domain/google_camera.dart';
import 'google_place_overlays.dart';

/// Google Maps als achtergrond onder de bestaande kaart.
///
/// De bovenliggende flutter_map blijft alles doen (gebaren, markers, ballonnen,
/// groepspin, auto-fit); deze kaart tekent de ondergrond en de plaatsen en
/// volgt de camera via [controller]. Zelf reageert ze niet op aanraking.
///
/// Plaatsen tekent Google zelf: die zitten zo vast aan de kaart en glijden niet
/// mee terwijl de camera even achterloopt tijdens het scrollen.
class GoogleBaseMap extends StatefulWidget {
  const GoogleBaseMap({
    super.key,
    required this.controller,
    required this.initialCenter,
    required this.initialZoom,
    this.satellite = false,
    this.bottomPadding = 0,
    this.places = const [],
  });

  final MapController controller;
  final LatLng initialCenter;
  final double initialZoom;
  final bool satellite;
  final List<Place> places;

  /// Hoogte van het onderpaneel: het Google-logo blijft erboven zichtbaar.
  final double bottomPadding;

  @override
  State<GoogleBaseMap> createState() => _GoogleBaseMapState();
}

class _GoogleBaseMapState extends State<GoogleBaseMap> {
  gm.GoogleMapController? _google;
  StreamSubscription<MapEvent>? _events;
  ({double latitude, double longitude, double zoom})? _wanted;
  ({double latitude, double longitude, double zoom})? _shown;
  bool _moving = false;
  final _icons = <String, gm.BitmapDescriptor>{};
  double? _iconPixelRatio;

  @override
  void initState() {
    super.initState();
    _wanted = (
      latitude: widget.initialCenter.latitude,
      longitude: widget.initialCenter.longitude,
      zoom: widget.initialZoom,
    );
    _events = widget.controller.mapEventStream.listen((event) {
      final camera = event.camera;
      _wanted = (latitude: camera.center.latitude, longitude: camera.center.longitude, zoom: camera.zoom);
      unawaited(_sync());
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _loadIcons();
  }

  /// Tekent elk gebruikt plaats-icoon één keer als bitmap.
  void _loadIcons() {
    final pixelRatio = MediaQuery.devicePixelRatioOf(context);
    if (_iconPixelRatio != pixelRatio) {
      _iconPixelRatio = pixelRatio;
      _icons.clear();
    }
    for (final key in widget.places.map((p) => p.icon).toSet()) {
      if (_icons.containsKey(key)) continue;
      unawaited(
        placeIconBitmap(placeIcon(key), color: AppColors.primary, size: 20, pixelRatio: pixelRatio).then((
          icon,
        ) {
          if (!mounted || _iconPixelRatio != pixelRatio) return;
          setState(() => _icons[key] = icon);
        }),
      );
    }
  }

  @override
  void didUpdateWidget(covariant GoogleBaseMap oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.places != widget.places) _loadIcons();
    if (oldWidget.bottomPadding != widget.bottomPadding) {
      _shown = null; // middelpunt verschuift mee met de padding
      unawaited(_sync());
    }
  }

  @override
  void dispose() {
    unawaited(_events?.cancel());
    super.dispose();
  }

  /// Eén verplaatsing tegelijk; tussentijdse camerastanden worden overgeslagen,
  /// enkel de laatste telt.
  Future<void> _sync() async {
    final google = _google;
    if (google == null || _moving) return;
    while (mounted) {
      final wanted = _wanted;
      if (wanted == null || !googleCameraChanged(_shown, wanted)) return;
      _moving = true;
      final target = googleCameraTarget(
        latitude: wanted.latitude,
        longitude: wanted.longitude,
        zoom: wanted.zoom,
        bottomPadding: widget.bottomPadding,
      );
      try {
        await google.moveCamera(
          gm.CameraUpdate.newCameraPosition(
            gm.CameraPosition(target: gm.LatLng(target.latitude, target.longitude), zoom: wanted.zoom),
          ),
        );
        _shown = wanted;
      } on Exception catch (error) {
        debugPrint('Google-kaart volgen mislukt: $error');
        return;
      } finally {
        _moving = false;
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final target = googleCameraTarget(
      latitude: widget.initialCenter.latitude,
      longitude: widget.initialCenter.longitude,
      zoom: widget.initialZoom,
      bottomPadding: widget.bottomPadding,
    );
    return gm.GoogleMap(
      initialCameraPosition: gm.CameraPosition(
        target: gm.LatLng(target.latitude, target.longitude),
        zoom: widget.initialZoom,
      ),
      mapType: widget.satellite ? gm.MapType.hybrid : gm.MapType.normal,
      circles: placeCircles(
        widget.places,
        color: AppColors.primary,
        pixelRatio: MediaQuery.devicePixelRatioOf(context),
      ),
      markers: placeMarkers(widget.places, _icons),
      padding: EdgeInsets.only(bottom: widget.bottomPadding),
      // Alle bediening zit in de kaart erboven.
      zoomGesturesEnabled: false,
      scrollGesturesEnabled: false,
      rotateGesturesEnabled: false,
      tiltGesturesEnabled: false,
      zoomControlsEnabled: false,
      myLocationButtonEnabled: false,
      mapToolbarEnabled: false,
      compassEnabled: false,
      indoorViewEnabled: false,
      onMapCreated: (controller) {
        _google = controller;
        unawaited(_sync());
      },
    );
  }
}
