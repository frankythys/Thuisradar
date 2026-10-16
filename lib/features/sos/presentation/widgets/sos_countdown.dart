import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../l10n/l10n.dart';

/// Aftellen na het vasthouden van de noodknop: een ring die leegloopt met de
/// resterende seconden, en een grote knop Annuleren. Pas als de tijd om is,
/// roept het [onDone] op. Verdwijnt het scherm (kruisje, terug), dan vertrekt
/// er niets: dat telt als annuleren.
class SosCountdown extends StatefulWidget {
  const SosCountdown({
    super.key,
    required this.duration,
    required this.onDone,
    required this.onCancel,
    this.size = 160,
  });

  final Duration duration;
  final VoidCallback onDone;
  final VoidCallback onCancel;

  /// Doorsnede van de ring.
  final double size;

  @override
  State<SosCountdown> createState() => _SosCountdownState();
}

class _SosCountdownState extends State<SosCountdown> with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(vsync: this, duration: widget.duration)
    ..addListener(_onTick)
    ..addStatusListener((status) {
      if (status == AnimationStatus.completed) widget.onDone();
    })
    ..forward();

  int _lastSecond = -1;

  int get _secondsLeft {
    final left = widget.duration * (1 - _controller.value);
    return (left.inMilliseconds / 1000).ceil();
  }

  void _onTick() {
    final second = _secondsLeft;
    if (second == _lastSecond) return;
    _lastSecond = second;
    // Elke seconde een tikje, zodat je het ook voelt zonder te kijken.
    if (second > 0) HapticFeedback.selectionClick();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;
    final size = widget.size;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        AnimatedBuilder(
          animation: _controller,
          builder: (context, _) {
            final seconds = _secondsLeft;
            return Semantics(
              liveRegion: true,
              label: context.l10n.sosAlarmIn(seconds),
              child: Container(
                width: size,
                height: size,
                decoration: BoxDecoration(shape: BoxShape.circle, color: scheme.error),
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    SizedBox(
                      width: size - 8,
                      height: size - 8,
                      child: CircularProgressIndicator(
                        value: 1 - _controller.value,
                        strokeWidth: 5,
                        color: scheme.onError,
                        backgroundColor: scheme.onError.withValues(alpha: .25),
                      ),
                    ),
                    ExcludeSemantics(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text('$seconds', style: text.displayLarge?.copyWith(color: scheme.onError)),
                          Text(
                            context.l10n.sosAlarmLeaving,
                            style: text.labelMedium?.copyWith(color: scheme.onError),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        ),
        SizedBox(height: size * .12),
        SizedBox(
          width: size * 1.3,
          child: FilledButton.icon(
            onPressed: widget.onCancel,
            icon: const Icon(Icons.close),
            label: Text(context.l10n.commonCancel),
            style: FilledButton.styleFrom(
              backgroundColor: scheme.inverseSurface,
              foregroundColor: scheme.onInverseSurface,
              minimumSize: Size.fromHeight(size * .36),
              textStyle: text.titleLarge,
            ),
          ),
        ),
      ],
    );
  }
}
