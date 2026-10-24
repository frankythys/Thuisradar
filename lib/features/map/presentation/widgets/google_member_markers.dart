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
/// - Plaats volgt meteen (~30x/s), met de afbeelding die er al is.
/// - Elke marker onthoudt enkele getekende varianten (inhoud + uitlijning):
///   wipt een ballon terug naar een eerdere stand, dan is die er meteen.
/// - Is er voor de nieuwe stand nog geen afbeelding, dan schuift de vorige
///   gewoon mee tot de nieuwe klaar is: een ballon bevriest nooit los van zijn
///   lid.
/// - Opnieuw tekenen gebeurt enkel als [MapMarkerSpec.imageKey] of de
///   uitlijning echt verandert, kort na elkaar samengenomen.
///
/// Een marker met [MapMarkerSpec.frames] (de wandel-GIF) wordt één keer per
/// beeld getekend; daarna wisselt enkel de afbeelding, op het tempo van de
/// GIF, zonder opnieuw te tekenen.
class GoogleMemberMarkers {
  GoogleMemberMarkers({required this.onChanged});

  /// Nieuwe markers om te tonen.
  final ValueChanged<Set<gm.Marker>> onChanged;

  /// Korte wachttijd zodat een reeks wijzigingen (zoomen) samen getekend wordt.
  static const _settle = Duration(milliseconds: 40);

  /// Hoogstens zo vaak beginnen met tekenen.
  static const _renderInterval = Duration(milliseconds: 200);

  /// Hoogstens zo vaak de plaats van bestaande markers bijwerken (~30x/s).
  static const _moveInterval = Duration(milliseconds: 33);

  /// Standaardruimte rond elk vak voor schaduw, gloed en lichtkring.
  static const _margin = 24.0;

  /// Waarschuwt in de console als de eerste markers te lang op hun
  /// voorbereiding wachten (afbeeldingen of de kaart). Zonder die melding zie
  /// je enkel dat er geen personen op de kaart staan, zonder reden.
  static const _readyWarnAfter = Duration(seconds: 10);

  /// Zoveel getekende varianten per marker blijven bewaard.
  static const _keepDrawn = 4;
  static const _keepAnimations = 3;

  Timer? _settleTimer;
  int _generation = 0;
  bool _rendering = false;
  bool _disposed = false;
  final _renderClock = Stopwatch();
  Widget Function(Widget)? _wrap;
  double _pixelRatio = 1;
  Future<void> _ready = Future<void>.value();
  List<MapMarkerSpec> _pending = const [];
  Set<gm.Marker> _shown = const {};
  final _moveClock = Stopwatch();
  Timer? _moveTimer;

  /// Getekende afbeeldingen per marker, nieuwste eerst.
  final _drawn = <String, List<_Drawn>>{};

  /// Laatst getekende spec per marker zonder [MapMarkerSpec.imageKey]: die
  /// wordt opnieuw getekend zodra er een nieuwe spec komt.
  final _drawnSpec = <String, MapMarkerSpec>{};

  /// Getekende beeldreeksen per geanimeerde marker, nieuwste eerst.
  final _animations = <String, List<_Animation>>{};
  int _frameIndex = 0;
  Timer? _frameTimer;

  /// Nieuwe berekening; posities meteen, gewijzigde inhoud kort daarna.
  void update(
    List<MapMarkerSpec> specs, {
    required Widget Function(Widget) wrap,
    required double pixelRatio,
    required Future<void> ready,
  }) {
    _pending = specs;
    _wrap = wrap;
    _pixelRatio = pixelRatio;
    _ready = ready;
    _moveSoon();
    if (specs.any((spec) => _needsDrawing(spec))) _scheduleRender();
  }

  void dispose() {
    _generation++;
    _disposed = true;
    _settleTimer?.cancel();
    _moveTimer?.cancel();
    _frameTimer?.cancel();
  }

  void _scheduleRender() {
    if (_disposed || _rendering || _settleTimer != null) return;
    final sinceLast = _renderClock.isRunning
        ? _renderClock.elapsed
        : _renderInterval;
    final wait = _renderInterval - sinceLast;
    _settleTimer = Timer(wait > _settle ? wait : _settle, () {
      _settleTimer = null;
      unawaited(_render(_wrap!, _pixelRatio, _ready));
    });
  }

  /// Plaatsupdate zonder opnieuw te tekenen, begrensd tot ~30x/s; de laatste
  /// stand komt er altijd door.
  void _moveSoon() {
    if (_moveTimer != null) return;
    final wait = _moveClock.isRunning
        ? _moveInterval - _moveClock.elapsed
        : Duration.zero;
    if (wait <= Duration.zero) {
      _move();
    } else {
      _moveTimer = Timer(wait, () {
        _moveTimer = null;
        _move();
      });
    }
  }

  void _move() {
    _moveClock
      ..reset()
      ..start();
    _emit(_build());
  }

  /// Alle markers voor de laatste berekening, met de best passende afbeelding.
  Set<gm.Marker> _build() => {
    for (final (index, spec) in _pending.indexed) ?_markerFor(spec, index),
  };

  gm.Marker? _markerFor(MapMarkerSpec spec, int index) {
    final frame = _frameOf(spec);
    // Een passende afbeelding is pixel voor pixel gelijk, maar het anker kan
    // verschoven zijn (bv. uitschuiven met een paar pixels): neem dus altijd
    // het anker van de huidige stand. Enkel een vorige afbeelding die nog niet
    // past, houdt haar eigen anker tot de nieuwe klaar is.
    final ({gm.BitmapDescriptor icon, Offset anchor})? look;
    if (spec.frames.isNotEmpty) {
      final match = _animationFor(spec, frame);
      final animation = match ?? _animations[spec.id]?.first;
      look = animation == null
          ? null
          : (
              icon: animation.icons[_frameIndex % animation.icons.length],
              anchor: match != null ? frame.anchor : animation.frame.anchor,
            );
    } else {
      final match = _drawnFor(spec, frame);
      final drawn = match ?? _drawn[spec.id]?.first;
      look = drawn == null
          ? null
          : (
              icon: drawn.icon,
              anchor: match != null ? frame.anchor : drawn.frame.anchor,
            );
    }
    if (look == null) return null; // nog nooit getekend
    return gm.Marker(
      markerId: gm.MarkerId(spec.id),
      position: gm.LatLng(spec.point.latitude, spec.point.longitude),
      icon: look.icon,
      anchor: look.anchor,
      zIndexInt: 10 + index,
    );
  }

  void _emit(Set<gm.Marker> markers) {
    _scheduleFrame();
    if (setEquals(markers, _shown)) return;
    final first = _shown.isEmpty && markers.isNotEmpty;
    _shown = markers;
    onChanged(markers);
    if (first) debugPrint('Markers op de kaart: ${markers.length}');
  }

  /// Volgend beeld op het tempo van de GIF, zolang er iets geanimeerd wordt.
  void _scheduleFrame() {
    final animated = [
      for (final spec in _pending)
        if (spec.frames.isNotEmpty) ?_animations[spec.id]?.first,
    ];
    if (animated.isEmpty) {
      _frameTimer?.cancel();
      _frameTimer = null;
      return;
    }
    if (_frameTimer != null) return;
    final durations = animated.first.durations;
    _frameTimer = Timer(durations[_frameIndex % durations.length], () {
      _frameTimer = null;
      if (_disposed) return;
      _frameIndex++;
      _emit(_build());
    });
  }

  NativeMarkerFrame _frameOf(MapMarkerSpec spec) => nativeMarkerFrame(
    size: Size(spec.width, spec.height),
    alignX: spec.alignment.x,
    alignY: spec.alignment.y,
    offset: spec.offset,
    margin: spec.margin ?? _margin,
  );

  _Drawn? _drawnFor(MapMarkerSpec spec, NativeMarkerFrame frame) {
    for (final drawn in _drawn[spec.id] ?? const <_Drawn>[]) {
      if (drawn.pixelRatio == _pixelRatio &&
          drawn.frame.canvas == frame.canvas &&
          drawn.frame.child == frame.child &&
          (spec.imageKey == null
              ? identical(_drawnSpec[spec.id], spec)
              : drawn.imageKey == spec.imageKey)) {
        return drawn;
      }
    }
    return null;
  }

  _Animation? _animationFor(MapMarkerSpec spec, NativeMarkerFrame frame) {
    for (final animation in _animations[spec.id] ?? const <_Animation>[]) {
      if (animation.pixelRatio == _pixelRatio &&
          animation.frame.canvas == frame.canvas &&
          animation.frame.child == frame.child &&
          animation.icons.length == spec.frames.length) {
        return animation;
      }
    }
    return null;
  }

  bool _needsDrawing(MapMarkerSpec spec) {
    final frame = _frameOf(spec);
    return spec.frames.isNotEmpty
        ? _animationFor(spec, frame) == null
        : _drawnFor(spec, frame) == null;
  }

  Future<void> _render(
    Widget Function(Widget) wrap,
    double pixelRatio,
    Future<void> ready,
  ) async {
    _rendering = true;
    _renderClock
      ..reset()
      ..start();
    final generation = ++_generation;
    final specs = _pending;
    final watchdog = Timer(
      _readyWarnAfter,
      () => debugPrint(
        'Markers wachten al ${_readyWarnAfter.inSeconds}s op de afbeeldingen of de kaart; '
        'nog niets getekend',
      ),
    );
    try {
      try {
        await ready;
      } finally {
        watchdog.cancel();
      }
      // Gewone markers eerst, en meteen tonen: een wandelanimatie (tot 19
      // beelden) mag de andere ballonnen niet laten wachten.
      for (final spec in specs) {
        if (generation != _generation) return;
        if (spec.frames.isNotEmpty || !_needsDrawing(spec)) continue;
        await _draw(spec, wrap, pixelRatio);
      }
      if (generation != _generation) return;
      final animated = [
        for (final spec in specs)
          if (spec.frames.isNotEmpty && _needsDrawing(spec)) spec,
      ];
      if (animated.isNotEmpty) _move();
      for (final spec in animated) {
        if (generation != _generation) return;
        await _drawAnimation(spec, wrap, pixelRatio);
      }
      if (generation != _generation) return;
      final ids = {for (final spec in specs) spec.id};
      _drawn.removeWhere((id, _) => !ids.contains(id));
      _drawnSpec.removeWhere((id, _) => !ids.contains(id));
      _animations.removeWhere(
        (id, _) => !specs.any((s) => s.id == id && s.frames.isNotEmpty),
      );
      _move(); // Altijd met de nieuwste plaats, niet die van bij het begin.
    } on Object catch (error) {
      debugPrint('Markers tekenen voor Google mislukt: $error');
    } finally {
      _rendering = false;
      if (!_disposed && _pending.any((spec) => _needsDrawing(spec))) {
        _scheduleRender();
      }
    }
  }

  Future<Uint8List> _png(
    Widget child,
    NativeMarkerFrame frame,
    Widget Function(Widget) wrap,
    double ratio,
  ) => renderWidgetToPng(
    wrap(
      Stack(
        clipBehavior: Clip.none,
        children: [Positioned.fromRect(rect: frame.child, child: child)],
      ),
    ),
    size: frame.canvas,
    pixelRatio: ratio,
  );

  /// Eén afbeelding. Is ze identiek aan een eerdere, dan blijft die afbeelding
  /// (geen onnodige update naar Google).
  Future<void> _draw(
    MapMarkerSpec spec,
    Widget Function(Widget) wrap,
    double pixelRatio,
  ) async {
    final frame = _frameOf(spec);
    final png = await _png(spec.child, frame, wrap, pixelRatio);
    final list = _drawn.putIfAbsent(spec.id, () => []);
    final same = list.where(
      (d) => d.pixelRatio == pixelRatio && d.frame.canvas == frame.canvas,
    );
    final reuse = same.where((d) => listEquals(d.png, png)).firstOrNull;
    list
      ..removeWhere((d) => identical(d, reuse))
      ..insert(0, (
        imageKey: spec.imageKey,
        pixelRatio: pixelRatio,
        frame: frame,
        png: png,
        icon: reuse?.icon ?? _bitmap(png, frame, pixelRatio),
      ));
    if (list.length > _keepDrawn) list.removeRange(_keepDrawn, list.length);
    _drawnSpec[spec.id] = spec;
  }

  /// Elk beeld van een animatie één keer getekend (opnieuw enkel voor een
  /// nieuwe uitlijning of schermdichtheid).
  Future<void> _drawAnimation(
    MapMarkerSpec spec,
    Widget Function(Widget) wrap,
    double pixelRatio,
  ) async {
    final frame = _frameOf(spec);
    final icons = <gm.BitmapDescriptor>[];
    for (final image in spec.frames) {
      icons.add(
        _bitmap(
          await _png(image.child, frame, wrap, pixelRatio),
          frame,
          pixelRatio,
        ),
      );
    }
    final list = _animations.putIfAbsent(spec.id, () => [])
      ..insert(0, (
        frame: frame,
        pixelRatio: pixelRatio,
        icons: icons,
        durations: [for (final image in spec.frames) image.duration],
      ));
    if (list.length > _keepAnimations) {
      list.removeRange(_keepAnimations, list.length);
    }
  }

  gm.BitmapDescriptor _bitmap(
    Uint8List png,
    NativeMarkerFrame frame,
    double pixelRatio,
  ) {
    // Android krijgt al fysieke schermpixels: voorkom een tweede schaalbewerking.
    if (!kIsWeb && defaultTargetPlatform == TargetPlatform.android) {
      return gm.BitmapDescriptor.bytes(
        png,
        bitmapScaling: gm.MapBitmapScaling.none,
      );
    }
    return gm.BitmapDescriptor.bytes(
      png,
      width: frame.canvas.width,
      height: frame.canvas.height,
      imagePixelRatio: pixelRatio,
    );
  }
}

typedef _Drawn = ({
  Object? imageKey,
  double pixelRatio,
  NativeMarkerFrame frame,
  Uint8List png,
  gm.BitmapDescriptor icon,
});

typedef _Animation = ({
  NativeMarkerFrame frame,
  double pixelRatio,
  List<gm.BitmapDescriptor> icons,
  List<Duration> durations,
});
