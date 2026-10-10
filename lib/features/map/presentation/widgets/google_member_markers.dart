import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart' as gm;

import '../../domain/native_marker_frame.dart';
import 'map_marker_spec.dart';
import 'widget_bitmap.dart';

/// Zet de berekende markers (leden, groepspinnen, ballonnen) om naar
/// Google-markers, zodat Google ze vast aan de kaart tekent.
///
/// Tekenen gebeurt pas als de kaartlaag even stil is (na scrollen of een
/// update), want elke marker is een afbeelding.
class GoogleMemberMarkers {
  GoogleMemberMarkers({required this.onChanged});

  /// Nieuwe markers om te tonen.
  final ValueChanged<Set<gm.Marker>> onChanged;

  static const _settle = Duration(milliseconds: 150);

  /// Ruimte rond elk vak voor schaduw, gloed en lichtkring.
  static const _margin = 24.0;

  Timer? _settleTimer;
  int _generation = 0;
  List<MapMarkerSpec> _pending = const [];
  final _cache = <String, ({Uint8List png, gm.Marker marker})>{};

  /// Nieuwe berekening van de kaartlaag; getekend zodra die even stil is.
  void update(
    List<MapMarkerSpec> specs, {
    required Widget Function(Widget) wrap,
    required double pixelRatio,
    required Future<void> ready,
  }) {
    _pending = specs;
    _settleTimer?.cancel();
    _settleTimer = Timer(_settle, () => unawaited(_render(wrap, pixelRatio, ready)));
  }

  void dispose() {
    _generation++;
    _settleTimer?.cancel();
  }

  Future<void> _render(Widget Function(Widget) wrap, double pixelRatio, Future<void> ready) async {
    final generation = ++_generation;
    final specs = _pending;
    await ready;
    final markers = <gm.Marker>{};
    try {
      for (final (index, spec) in specs.indexed) {
        if (generation != _generation) return;
        markers.add(await _marker(spec, index, wrap, pixelRatio));
      }
    } on Object catch (error) {
      debugPrint('Markers tekenen voor Google mislukt: $error');
      return;
    }
    if (generation != _generation) return;
    _cache.removeWhere((id, _) => !specs.any((s) => s.id == id));
    onChanged(markers);
  }

  /// Eén marker als afbeelding. Is het beeld identiek aan het vorige, dan
  /// blijft de oude marker (geen onnodige update naar Google).
  Future<gm.Marker> _marker(
    MapMarkerSpec spec,
    int index,
    Widget Function(Widget) wrap,
    double pixelRatio,
  ) async {
    final frame = nativeMarkerFrame(
      size: Size(spec.width, spec.height),
      alignX: spec.alignment.x,
      alignY: spec.alignment.y,
      offset: spec.offset,
      margin: _margin,
    );
    final png = await renderWidgetToPng(
      wrap(
        Stack(
          clipBehavior: Clip.none,
          children: [Positioned.fromRect(rect: frame.child, child: spec.child)],
        ),
      ),
      size: frame.canvas,
      pixelRatio: pixelRatio,
    );
    final position = gm.LatLng(spec.point.latitude, spec.point.longitude);
    final cached = _cache[spec.id];
    if (cached != null &&
        listEquals(cached.png, png) &&
        cached.marker.position == position &&
        cached.marker.zIndexInt == 10 + index) {
      return cached.marker;
    }
    final marker = gm.Marker(
      markerId: gm.MarkerId(spec.id),
      position: position,
      icon: gm.BitmapDescriptor.bytes(png, width: frame.canvas.width, height: frame.canvas.height),
      anchor: frame.anchor,
      zIndexInt: 10 + index,
    );
    _cache[spec.id] = (png: png, marker: marker);
    return marker;
  }
}
