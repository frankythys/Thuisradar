import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_map/flutter_map.dart';

import '../data/map_view_store.dart';
import '../domain/map_view.dart';

/// Bewaart waar de kaart staat, telkens ze even stilligt na een beweging
/// (door de gebruiker of de app). Zo opent de kaart de volgende keer meteen
/// op die plek.
class MapViewRecorder {
  MapViewRecorder(this._controller, this._store, {this.quiet = const Duration(milliseconds: 1500)});

  final MapController _controller;
  final MapViewStore _store;

  /// Zo lang moet de kaart stilliggen voor we bewaren.
  final Duration quiet;

  StreamSubscription<MapEvent>? _events;
  Timer? _pending;

  void start() {
    _events ??= _controller.mapEventStream.listen((_) {
      _pending?.cancel();
      _pending = Timer(quiet, _save);
    });
  }

  void _save() {
    final camera = _controller.camera;
    final view = MapView(
      latitude: camera.center.latitude,
      longitude: camera.center.longitude,
      zoom: camera.zoom,
    );
    _store.write(view).catchError((Object error) => debugPrint('Kaartpositie bewaren mislukt: $error'));
  }

  void dispose() {
    _pending?.cancel();
    unawaited(_events?.cancel());
  }
}
