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
/// Opnieuw tekenen gebeurt pas als de kaartlaag even stil is, want elke
/// marker is een afbeelding. Verandert enkel de plaats (bv. tijdens het
/// rijden), dan schuift de bestaande afbeelding meteen mee: vloeiend, zonder
/// te wachten.
class GoogleMemberMarkers {
  GoogleMemberMarkers({required this.onChanged});

  /// Nieuwe markers om te tonen.
  final ValueChanged<Set<gm.Marker>> onChanged;

  static const _settle = Duration(milliseconds: 150);

  /// Hoogstens zo vaak de plaats van bestaande markers bijwerken (~30x/s).
  static const _moveInterval = Duration(milliseconds: 33);

  /// Ruimte rond elk vak voor schaduw, gloed en lichtkring.
  static const _margin = 24.0;

  Timer? _settleTimer;
  int _generation = 0;
  List<MapMarkerSpec> _pending = const [];
  final _cache = <String, ({Uint8List png, gm.Marker marker, NativeMarkerFrame frame})>{};
  Set<gm.Marker> _shown = const {};
  final _moveClock = Stopwatch();
  Timer? _moveTimer;

  /// Nieuwe berekening van de kaartlaag; getekend zodra die even stil is.
  void update(
    List<MapMarkerSpec> specs, {
    required Widget Function(Widget) wrap,
    required double pixelRatio,
    required Future<void> ready,
  }) {
    _pending = specs;
    _moveSoon();
    _settleTimer?.cancel();
    _settleTimer = Timer(_settle, () => unawaited(_render(wrap, pixelRatio, ready)));
  }

  void dispose() {
    _generation++;
    _settleTimer?.cancel();
    _moveTimer?.cancel();
  }

  /// Plaatsupdate zonder opnieuw te tekenen, begrensd tot ~30x/s; de laatste
  /// stand komt er altijd door.
  void _moveSoon() {
    if (_moveTimer != null) return;
    final wait = _moveClock.isRunning ? _moveInterval - _moveClock.elapsed : Duration.zero;
    if (wait <= Duration.zero) {
      _move();
    } else {
      _moveTimer = Timer(wait, () {
        _moveTimer = null;
        _move();
      });
    }
  }

  /// Bestaande afbeeldingen naar hun nieuwe plaats, als hun uitzicht (vak en
  /// uitlijning) gelijk bleef. Andere markers blijven staan tot het tekenen.
  void _move() {
    _moveClock
      ..reset()
      ..start();
    final shownById = {for (final m in _shown) m.markerId.value: m};
    final moved = <gm.Marker>{};
    for (final (index, spec) in _pending.indexed) {
      final cached = _cache[spec.id];
      final frame = _frameOf(spec);
      if (cached != null && cached.frame.canvas == frame.canvas && cached.frame.child == frame.child) {
        moved.add(
          cached.marker.copyWith(
            positionParam: gm.LatLng(spec.point.latitude, spec.point.longitude),
            zIndexIntParam: 10 + index,
          ),
        );
      } else if (shownById[spec.id] case final previous?) {
        moved.add(previous);
      }
    }
    _emit(moved);
  }

  void _emit(Set<gm.Marker> markers) {
    if (setEquals(markers, _shown)) return;
    _shown = markers;
    onChanged(markers);
  }

  NativeMarkerFrame _frameOf(MapMarkerSpec spec) => nativeMarkerFrame(
    size: Size(spec.width, spec.height),
    alignX: spec.alignment.x,
    alignY: spec.alignment.y,
    offset: spec.offset,
    margin: _margin,
  );

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
    _emit(markers);
  }

  /// Eén marker als afbeelding. Is het beeld identiek aan het vorige, dan
  /// blijft de oude marker (geen onnodige update naar Google).
  Future<gm.Marker> _marker(
    MapMarkerSpec spec,
    int index,
    Widget Function(Widget) wrap,
    double pixelRatio,
  ) async {
    final frame = _frameOf(spec);
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
    _cache[spec.id] = (png: png, marker: marker, frame: frame);
    return marker;
  }
}
