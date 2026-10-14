import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import 'member_history_bubble.dart';
import 'walking_sneakers.dart';

/// De wandelende sneakers boven de Google-kaart, als gewone Flutter-widget.
///
/// Elk nieuw markerbeeld liet Google de kaart opnieuw tekenen, en dan
/// knipperde de tekst in de ballonnen. Nu tekent Google enkel een stilstaand
/// beeld van de schoenen in de ballon, en speelt de animatie hier, erboven.
///
/// Een wit vlak in de kleur van de ballon dekt dat stilstaande beeld af. De
/// Google-kaart volgt de kaart erboven met een kleine vertraging: tijdens
/// schuiven, zoomen of draaien verdwijnt deze laag daarom even, zodat de
/// schoenen nooit naast hun vak staan. Na [settle] stilstand komt ze terug.
class GoogleWalkerOverlay extends StatefulWidget {
  const GoogleWalkerOverlay({super.key, required this.width, required this.height});

  /// Zo lang moet de kaart stilstaan voor de animatie terugkomt.
  static const settle = Duration(milliseconds: 300);

  /// Duur van het invloeien; verdwijnen gebeurt meteen.
  static const fadeIn = Duration(milliseconds: 150);

  /// Grootte van het vak van de sneakers (zonder de rand van [bleed]).
  final double width;
  final double height;

  /// Zoveel ruimer dan het vak is het witte vlak, zodat het stilstaande beeld
  /// ook bij een halve pixel verschil volledig bedekt blijft.
  static const bleed = 1.0;

  @override
  State<GoogleWalkerOverlay> createState() => _GoogleWalkerOverlayState();
}

typedef _CameraState = ({LatLng center, double zoom, double rotation, Size size});

class _GoogleWalkerOverlayState extends State<GoogleWalkerOverlay> {
  _CameraState? _camera;
  bool _moving = false;
  Timer? _settleTimer;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final camera = MapCamera.maybeOf(context);
    if (camera == null) return;
    final now = (
      center: camera.center,
      zoom: camera.zoom,
      rotation: camera.rotation,
      size: camera.nonRotatedSize,
    );
    final before = _camera;
    _camera = now;
    if (before == null || before == now) return;
    // Hier volgt sowieso een build: geen setState nodig.
    _moving = true;
    _settleTimer?.cancel();
    _settleTimer = Timer(GoogleWalkerOverlay.settle, () {
      if (mounted) setState(() => _moving = false);
    });
  }

  @override
  void dispose() {
    _settleTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => IgnorePointer(
    child: AnimatedOpacity(
      opacity: _moving ? 0 : 1,
      duration: _moving ? Duration.zero : GoogleWalkerOverlay.fadeIn,
      child: TickerMode(
        enabled: !_moving,
        child: ColoredBox(
          color: kBubbleColor,
          child: Center(
            child: WalkingSneakers(width: widget.width, height: widget.height),
          ),
        ),
      ),
    ),
  );
}
