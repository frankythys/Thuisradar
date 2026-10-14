import 'package:flutter/widgets.dart';
import 'package:flutter_map/flutter_map.dart';

import '../../domain/twist_gesture.dart';

/// Gebaren op de gezinskaart, zoals in Google Maps: slepen, knijpen en, na een
/// duidelijke draai met twee vingers (zie [TwistGesture]), ook draaien.
/// Zoomen en verschuiven werken in hetzelfde gebaar gewoon door.
InteractionOptions familyMapGestures({required bool rotate}) =>
    InteractionOptions(flags: rotate ? InteractiveFlag.all : InteractiveFlag.all & ~InteractiveFlag.rotate);

/// Volgt de vingers boven de kaart en geeft aan [builder] door of draaien
/// in het huidige gebaar toegelaten is.
///
/// flutter_map heeft zelf een drempel, maar vergelijkt die met Flutters
/// ruwe, niet-genormaliseerde hoek (+1° kan -359° zijn). Daardoor draaide de
/// kaart bij elke kleine draai. Hier gebeurt de drempel op de juiste hoek.
class TwistToRotate extends StatefulWidget {
  const TwistToRotate({super.key, required this.builder});

  final Widget Function(BuildContext context, bool rotate) builder;

  @override
  State<TwistToRotate> createState() => _TwistToRotateState();
}

class _TwistToRotateState extends State<TwistToRotate> {
  final _twist = TwistGesture();

  void _update(void Function(TwistGesture twist) change) {
    final before = _twist.rotating;
    change(_twist);
    if (_twist.rotating != before) setState(() {});
  }

  static TouchPoint _at(PointerEvent event) => (x: event.position.dx, y: event.position.dy);

  @override
  Widget build(BuildContext context) {
    return Listener(
      onPointerDown: (event) => _update((twist) => twist.down(event.pointer, _at(event))),
      onPointerMove: (event) => _update((twist) => twist.move(event.pointer, _at(event))),
      onPointerUp: (event) => _update((twist) => twist.up(event.pointer)),
      onPointerCancel: (event) => _update((twist) => twist.up(event.pointer)),
      child: widget.builder(context, _twist.rotating),
    );
  }
}
