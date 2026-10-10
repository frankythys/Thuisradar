import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart' as gm;
import 'package:latlong2/latlong.dart';

import '../../domain/google_camera.dart';

/// Google Maps als achtergrond onder de bestaande kaart.
///
/// De bovenliggende flutter_map blijft alles doen (gebaren, markers, ballonnen,
/// groepspin, auto-fit); deze kaart tekent enkel de ondergrond en volgt de
/// camera via [controller]. Zelf reageert ze niet op aanraking.
class GoogleBaseMap extends StatefulWidget {
  const GoogleBaseMap({
    super.key,
    required this.controller,
    required this.initialCenter,
    required this.initialZoom,
    this.satellite = false,
    this.bottomPadding = 0,
  });

  final MapController controller;
  final LatLng initialCenter;
  final double initialZoom;
  final bool satellite;

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
  void didUpdateWidget(covariant GoogleBaseMap oldWidget) {
    super.didUpdateWidget(oldWidget);
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
