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
  /// native Google-kaart niet. Bouw de kaart opnieuw zodra Android het scherm
  /// weer heeft gekoppeld en zichtbaar maakt. Tijdens `detached` is er nog
  /// geen platformoppervlak; daar alvast een kaart maken kan markers kwijt.
  late final AppLifecycleListener _lifecycle;
  int _screen = 0;
  bool _detached = false;
  bool _rebuildScheduled = false;

  @override
  void initState() {
    super.initState();
    _lifecycle = AppLifecycleListener(
      onDetach: () => _detached = true,
      onResume: _rebuildAfterDetach,
    );
  }

  void _rebuildAfterDetach() {
    if (!_detached || _rebuildScheduled) return;
    _detached = false;
    _rebuildScheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _rebuildScheduled = false;
      if (mounted) setState(() => _screen++);
    });
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
          child: KeyedSubtree(
            key: ValueKey(_screen),
            child: widget.base(_markers),
          ),
        ),
        widget.overlay((markers) => _markers.value = markers),
      ],
    );
  }
}
