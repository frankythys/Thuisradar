import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';

import '../../domain/map_rotation.dart';
import '../../../../l10n/l10n.dart';

/// Kompas zoals in Google Maps: verschijnt zodra de kaart gedraaid is, wijst
/// naar het noorden en draait de kaart bij een tik vloeiend terug.
class MapCompassButton extends StatefulWidget {
  const MapCompassButton({super.key, required this.controller});

  final MapController controller;

  @override
  State<MapCompassButton> createState() => _MapCompassButtonState();
}

class _MapCompassButtonState extends State<MapCompassButton> with SingleTickerProviderStateMixin {
  static const _duration = Duration(milliseconds: 300);

  late final _turn = AnimationController(vsync: this, duration: _duration)..addListener(_onTurn);
  StreamSubscription<MapEvent>? _events;
  double _rotation = 0;
  double _from = 0;

  @override
  void initState() {
    super.initState();
    _events = widget.controller.mapEventStream.listen((event) {
      // De gebruiker draait zelf weer: niet tegenwerken.
      if (event.source != MapEventSource.mapController && _turn.isAnimating) _turn.stop();
      final rotation = event.camera.rotation;
      if (rotation != _rotation && mounted) setState(() => _rotation = rotation);
    });
  }

  @override
  void dispose() {
    unawaited(_events?.cancel());
    _turn.dispose();
    super.dispose();
  }

  void _onTurn() {
    widget.controller.rotate(_from * (1 - Curves.easeOut.transform(_turn.value)));
  }

  void _toNorth() {
    _from = normalizedRotation(_rotation);
    unawaited(_turn.forward(from: 0));
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final visible = isRotated(_rotation);
    return IgnorePointer(
      ignoring: !visible,
      child: AnimatedScale(
        scale: visible ? 1 : 0.6,
        duration: const Duration(milliseconds: 150),
        child: AnimatedOpacity(
          opacity: visible ? 1 : 0,
          duration: const Duration(milliseconds: 150),
          child: Material(
            color: colors.surface,
            shape: const CircleBorder(),
            elevation: 3,
            child: InkWell(
              onTap: _toNorth,
              customBorder: const CircleBorder(),
              child: Tooltip(
                message: context.l10n.mapNorthUp,
                child: SizedBox(
                  width: 48,
                  height: 48,
                  // Zelfde draaiing als de kaart: de naald wijst naar het noorden.
                  child: Transform.rotate(
                    angle: normalizedRotation(_rotation) * math.pi / 180,
                    child: Icon(Icons.navigation, color: colors.primary),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
