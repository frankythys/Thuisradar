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
/// update), want elke marker is een afbeelding. Een marker met lichtkring
/// krijgt [pulseFrames] beelden die elkaar afwisselen.
class GoogleMemberMarkers {
  GoogleMemberMarkers({required this.onChanged});

  /// Nieuwe set markers om te tonen.
  final ValueChanged<Set<gm.Marker>> onChanged;

  static const pulseFrames = 8;
  static const _settle = Duration(milliseconds: 150);
  static const _frameTime = Duration(milliseconds: 1600 ~/ pulseFrames);

  /// Ruimte rond elk vak voor schaduw, gloed en lichtkring.
  static const _margin = 24.0;

  Timer? _settleTimer;
  Timer? _pulseTimer;
  int _generation = 0;
  List<MapMarkerSpec> _pending = const [];
  final _cache = <String, ({Uint8List png, gm.Marker marker})>{};
  Set<gm.Marker> _still = const {};
  ({String id, List<gm.Marker> frames})? _pulse;
  int _pulseIndex = 0;

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
    _pulseTimer?.cancel();
  }

  Future<void> _render(Widget Function(Widget) wrap, double pixelRatio, Future<void> ready) async {
    final generation = ++_generation;
    final specs = _pending;
    await ready;
    final still = <gm.Marker>{};
    ({String id, List<gm.Marker> frames})? pulse;
    try {
      for (final (index, spec) in specs.indexed) {
        if (generation != _generation) return;
        final animated = spec.animated;
        if (animated != null) {
          pulse = (
            id: spec.id,
            frames: [
              for (var i = 0; i < pulseFrames; i++)
                await _marker(
                  spec,
                  animated(i / pulseFrames),
                  index,
                  wrap,
                  pixelRatio,
                  cacheKey: '${spec.id}#$i',
                ),
            ],
          );
        } else {
          still.add(await _marker(spec, spec.child, index, wrap, pixelRatio, cacheKey: spec.id));
        }
      }
    } on Object catch (error) {
      debugPrint('Markers tekenen voor Google mislukt: $error');
      return;
    }
    if (generation != _generation) return;
    _cache.removeWhere((key, _) => !specs.any((s) => key == s.id || key.startsWith('${s.id}#')));
    _still = still;
    _pulse = pulse;
    _pulseIndex = 0;
    _pulseTimer?.cancel();
    if (pulse != null) {
      _pulseTimer = Timer.periodic(_frameTime, (_) {
        _pulseIndex = (_pulseIndex + 1) % pulseFrames;
        _emit();
      });
    }
    _emit();
  }

  void _emit() {
    final pulse = _pulse;
    onChanged({..._still, if (pulse != null) pulse.frames[_pulseIndex]});
  }

  /// Eén marker als afbeelding. Is het beeld identiek aan het vorige, dan
  /// blijft de oude marker (geen onnodige update naar Google).
  Future<gm.Marker> _marker(
    MapMarkerSpec spec,
    Widget child,
    int index,
    Widget Function(Widget) wrap,
    double pixelRatio, {
    required String cacheKey,
  }) async {
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
          children: [Positioned.fromRect(rect: frame.child, child: child)],
        ),
      ),
      size: frame.canvas,
      pixelRatio: pixelRatio,
    );
    final position = gm.LatLng(spec.point.latitude, spec.point.longitude);
    final cached = _cache[cacheKey];
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
    _cache[cacheKey] = (png: png, marker: marker);
    return marker;
  }
}
