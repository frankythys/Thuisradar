import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';

import '../../domain/map_style.dart';

/// Zwevende knop: wisselen tussen gewone kaart en satelliet (Google Maps).
///
/// Toont en wisselt wat er echt te zien is: ook wanneer de kaart op
/// straatniveau automatisch satelliet toont, zet een tik hem op gewoon.
class MapStyleButton extends StatefulWidget {
  const MapStyleButton({super.key, required this.controller, required this.choice, required this.onChoose});

  final MapController controller;

  /// Keuze tot nu toe; `null` = automatisch.
  final bool? choice;

  final void Function({required bool satellite}) onChoose;

  @override
  State<MapStyleButton> createState() => _MapStyleButtonState();
}

class _MapStyleButtonState extends State<MapStyleButton> {
  StreamSubscription<MapEvent>? _events;
  double _zoom = 0;

  @override
  void initState() {
    super.initState();
    _events = widget.controller.mapEventStream.listen((event) {
      final zoom = event.camera.zoom;
      final wasSatellite = showsSatellite(choice: widget.choice, zoom: _zoom);
      _zoom = zoom;
      if (showsSatellite(choice: widget.choice, zoom: zoom) != wasSatellite && mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    unawaited(_events?.cancel());
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final satellite = showsSatellite(choice: widget.choice, zoom: _zoom);
    return Material(
      color: colors.surface,
      shape: const CircleBorder(),
      elevation: 3,
      child: InkWell(
        onTap: () => widget.onChoose(satellite: !satellite),
        customBorder: const CircleBorder(),
        child: Tooltip(
          message: satellite ? 'Gewone kaart' : 'Satelliet',
          child: SizedBox(
            width: 48,
            height: 48,
            child: Icon(satellite ? Icons.map_outlined : Icons.satellite_alt_outlined, color: colors.primary),
          ),
        ),
      ),
    );
  }
}
