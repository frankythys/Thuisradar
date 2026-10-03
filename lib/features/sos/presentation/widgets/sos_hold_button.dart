import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../core/theme/app_colors.dart';
import '../../domain/sos_alert.dart';

/// Burnt-orange noodknop die je [kSosHoldDuration] moet vasthouden om af te gaan.
/// Voorkomt vals alarm; loslaten annuleert.
class SosHoldButton extends StatefulWidget {
  const SosHoldButton({super.key, required this.onActivate});

  final Future<void> Function() onActivate;

  @override
  State<SosHoldButton> createState() => _SosHoldButtonState();
}

class _SosHoldButtonState extends State<SosHoldButton> with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(vsync: this, duration: kSosHoldDuration)
    ..addStatusListener(_onStatus);

  bool _fired = false;

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

  void _start(_) {
    _fired = false;
    _controller.forward(from: 0);
  }

  void _cancel([_]) {
    if (!_fired) _controller.reverse();
  }

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;

    return GestureDetector(
      onTapDown: _start,
      onTapUp: _cancel,
      onTapCancel: _cancel,
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, _) {
          final holding = _controller.value > 0;
          return Container(
            height: 44,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            decoration: const ShapeDecoration(color: AppColors.alert, shape: StadiumBorder()),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                SizedBox(
                  width: 20,
                  height: 20,
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      if (holding)
                        CircularProgressIndicator(
                          value: _controller.value,
                          strokeWidth: 2,
                          color: Colors.white,
                          backgroundColor: Colors.white24,
                        ),
                      const Icon(Icons.shield_outlined, size: 16, color: Colors.white),
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
