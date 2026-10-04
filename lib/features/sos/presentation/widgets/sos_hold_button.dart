import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../core/theme/app_colors.dart';
import '../../domain/sos_alert.dart';

/// Burnt-orange noodknop die je [kSosHoldDuration] moet vasthouden om af te gaan.
///
/// Gebruikt een [Listener] met opaque hit-test, zodat de kaart eronder de touch
/// niet overneemt. Kleine vingerbewegingen (tot [_moveTolerance]) breken het
/// vasthouden niet af. Korte tril bij start, sterke tril bij activatie.
class SosHoldButton extends StatefulWidget {
  const SosHoldButton({
    super.key,
    required this.onActivate,
    this.large = false,
  });

  final Future<void> Function() onActivate;
  final bool large;

  @override
  State<SosHoldButton> createState() => _SosHoldButtonState();
}

class _SosHoldButtonState extends State<SosHoldButton>
    with SingleTickerProviderStateMixin {
  static const _moveTolerance = 20.0;
  static const _size = 56.0;

  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: kSosHoldDuration,
  )..addStatusListener(_onStatus);

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
    await HapticFeedback.heavyImpact();
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

    return Listener(
      behavior: HitTestBehavior.opaque,
      onPointerDown: _onDown,
      onPointerMove: _onMove,
      onPointerUp: _cancel,
      onPointerCancel: _cancel,
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, _) {
          final holding = _controller.value > 0;
          if (widget.large) {
            return Container(
              width: 160,
              height: 160,
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                color: Color(0xFF7B3500),
              ),
              child: Stack(
                alignment: Alignment.center,
                children: [
                  if (holding)
                    SizedBox(
                      width: 154,
                      height: 154,
                      child: CircularProgressIndicator(
                        value: _controller.value,
                        strokeWidth: 5,
                        color: Colors.white,
                        backgroundColor: Colors.white24,
                      ),
                    ),
                  Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(
                        Icons.warning_amber_rounded,
                        color: Colors.white,
                        size: 34,
                      ),
                      Text(
                        'SOS',
                        style: text.headlineLarge?.copyWith(
                          color: Colors.white,
                          letterSpacing: 3,
                        ),
                      ),
                      Text(
                        holding ? 'BLIJF VASTHOUDEN' : 'HOUD INGEDRUKT',
                        style: const TextStyle(
                          fontSize: 10,
                          color: Colors.white,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            );
          }
          return Container(
            height: _size,
            padding: const EdgeInsets.symmetric(horizontal: 18),
            decoration: const ShapeDecoration(
              color: AppColors.alert,
              shape: StadiumBorder(),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                SizedBox(
                  width: 28,
                  height: 28,
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      if (holding)
                        CircularProgressIndicator(
                          value: _controller.value,
                          strokeWidth: 3,
                          color: Colors.white,
                          backgroundColor: Colors.white30,
                        ),
                      const Icon(
                        Icons.shield_outlined,
                        size: 18,
                        color: Colors.white,
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  holding ? 'Blijf vasthouden…' : 'SOS',
                  style: text.labelLarge?.copyWith(color: Colors.white),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}
