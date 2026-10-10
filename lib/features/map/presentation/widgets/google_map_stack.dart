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

  @override
  void dispose() {
    _markers.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Positioned.fill(child: widget.base(_markers)),
        widget.overlay((markers) => _markers.value = markers),
      ],
    );
  }
}
