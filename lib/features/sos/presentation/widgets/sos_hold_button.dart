import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../domain/sos_alert.dart';

/// Ronde noodknop in de alarmkleur die je [kSosHoldDuration] moet vasthouden
/// om af te gaan.
///
/// Gebruikt een [Listener] met opaque hit-test, zodat niets eronder de touch
/// overneemt. Kleine vingerbewegingen (tot [_moveTolerance]) breken het
/// vasthouden niet af. Korte tril bij start, sterke tril bij activatie.
class SosHoldButton extends StatefulWidget {
  const SosHoldButton({super.key, required this.onActivate, this.size = 160});

  final Future<void> Function() onActivate;

  /// Doorsnede van de knop.
  final double size;

  @override
  State<SosHoldButton> createState() => _SosHoldButtonState();
}

class _SosHoldButtonState extends State<SosHoldButton> with SingleTickerProviderStateMixin {
  static const _moveTolerance = 20.0;

  late final AnimationController _controller = AnimationController(vsync: this, duration: kSosHoldDuration)
    ..addStatusListener(_onStatus);

  bool _fired = false;
  Offset? _start;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _onStatus(AnimationStatus status) {
    if (status == AnimationStatus.completed && !_fired) {
      _fired = true;
      _activate();
    }
  }

  Future<void> _activate() async {
    // Niet op de tril wachten: het alarm gaat meteen weg.
    unawaited(HapticFeedback.heavyImpact());
    await widget.onActivate();
    if (mounted) _controller.reverse();
    _fired = false;
  }

  void _onDown(PointerDownEvent event) {
    _start = event.position;
    _fired = false;
    HapticFeedback.lightImpact();
    _controller.forward(from: 0);
  }

  void _onMove(PointerMoveEvent event) {
    final start = _start;
    if (start != null && (event.position - start).distance > _moveTolerance) {
      _cancel();
    }
  }

  void _cancel([PointerEvent? _]) {
    _start = null;
    if (!_fired) _controller.reverse();
  }

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;
    final size = widget.size;
    final onAlert = scheme.onError;

    return Semantics(
      button: true,
      label: 'SOS, houd ingedrukt',
      child: Listener(
        behavior: HitTestBehavior.opaque,
        onPointerDown: _onDown,
        onPointerMove: _onMove,
        onPointerUp: _cancel,
        onPointerCancel: _cancel,
        child: AnimatedBuilder(
          animation: _controller,
          builder: (context, _) {
            final holding = _controller.value > 0;
            return Container(
              width: size,
              height: size,
              decoration: BoxDecoration(shape: BoxShape.circle, color: scheme.error),
              child: Stack(
                alignment: Alignment.center,
                children: [
                  if (holding)
                    SizedBox(
                      width: size - 8,
                      height: size - 8,
                      child: CircularProgressIndicator(
                        value: _controller.value,
                        strokeWidth: 5,
                        color: onAlert,
                        backgroundColor: onAlert.withValues(alpha: .25),
                      ),
                    ),
                  Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text('SOS', style: text.displayLarge?.copyWith(color: onAlert, letterSpacing: 4)),
                      Text(
                        holding ? 'Blijf vasthouden' : 'Houd ingedrukt',
                        style: text.labelMedium?.copyWith(color: onAlert),
                      ),
                    ],
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}
