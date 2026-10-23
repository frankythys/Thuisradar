import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import 'map_marker_spec.dart';

/// Google Maps onderaan, de bestaande kaart (gebaren + tikvlakken) erboven.
/// Geeft de markers die de kaart erboven berekent door aan Google.
class GoogleMapStack extends StatefulWidget {
  const GoogleMapStack({super.key, required this.base, required this.overlay});

  final Widget Function(ValueListenable<List<MapMarkerSpec>> markers) base;
  final Widget Function(ValueChanged<List<MapMarkerSpec>> onMarkers) overlay;

  @override
  State<GoogleMapStack> createState() => _GoogleMapStackState();
}

class _GoogleMapStackState extends State<GoogleMapStack> {
  final _markers = ValueNotifier<List<MapMarkerSpec>>(const []);

  /// De Flutter-engine overleeft het Android-scherm (zie MainActivity), de
  /// native Google-kaart niet: die hoort bij het gesloten scherm. Na elke
  /// ontkoppeling bouwen we daarom een nieuwe kaart (nieuwe sleutel), ook als
  /// er tussendoor geen enkel beeld getekend werd.
  late final AppLifecycleListener _lifecycle;
  int _screen = 0;

  @override
  void initState() {
    super.initState();
    _lifecycle = AppLifecycleListener(onDetach: () => setState(() => _screen++));
  }

  @override
  void dispose() {
    _lifecycle.dispose();
    _markers.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Positioned.fill(
          child: KeyedSubtree(key: ValueKey(_screen), child: widget.base(_markers)),
        ),
        widget.overlay((markers) => _markers.value = markers),
      ],
    );
  }
}
