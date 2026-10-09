import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../../../core/theme/app_colors.dart';
import 'scene_bits.dart';

/// Noodknop die vastgehouden wordt tot het alarm vertrekt naar het gezin.
class SosScene extends AnimatedScene {
  const SosScene({super.key, required super.progress});

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    // Vasthouden: de ring loopt vol en de knop zakt een beetje in.
    final hold = phase(t, .05, .7, Curves.linear);
    final sent = t >= .72;
    final ripple = phase(t, .7, 1);
    final pill = phase(t, .75, 1, Curves.easeOutBack);
    return Stack(
      clipBehavior: Clip.none,
      children: [
        SceneDot(
          x: 140,
          y: 108,
          size: 196 + 40 * ripple,
          child: DecoratedBox(
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: AppColors.alert.withValues(alpha: .08 + .1 * (sent ? 1 - ripple : 0)),
            ),
          ),
        ),
        SceneDot(
          x: 140,
          y: 108,
          size: 160,
          child: CustomPaint(painter: _HoldRingPainter(progress: hold)),
        ),
        SceneDot(
          x: 140,
          y: 108,
          size: 136,
          child: Transform.scale(
            scale: sent ? 1 : 1 - .05 * phase(t, 0, .12),
            child: DecoratedBox(
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white, width: 6),
                gradient: const RadialGradient(
                  center: Alignment(-.3, -.4),
                  colors: [Color(0xFFD2551F), AppColors.alert],
                ),
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text('SOS', style: text.headlineLarge?.copyWith(color: Colors.white, letterSpacing: 2)),
                  Text(
                    sent ? 'Verstuurd' : 'Houd 3 sec. vast',
                    style: text.labelMedium?.copyWith(color: Colors.white),
                  ),
                ],
              ),
            ),
          ),
        ),
        Positioned(
          left: 8,
          right: 8,
          bottom: 8,
          child: Opacity(
            opacity: pill.clamp(0.0, 1.0),
            child: Transform.scale(
              scale: .6 + .4 * pill,
              child: Center(
                child: Container(
                  padding: const EdgeInsets.fromLTRB(7, 7, 12, 7),
                  decoration: const ShapeDecoration(
                    color: Colors.white,
                    shape: StadiumBorder(),
                    shadows: sceneShadow,
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      SizedBox(
                        width: 52,
                        height: 22,
                        child: Stack(
                          children: [
                            for (final (i, (letter, color)) in [
                              ('P', AppColors.forMemberIndex(0)),
                              ('M', AppColors.forMemberIndex(4)),
                              ('L', AppColors.forMemberIndex(2)),
                            ].indexed)
                              Positioned(
                                left: i * 15.0,
                                width: 22,
                                height: 22,
                                child: _MiniAvatar(letter: letter, color: color),
                              ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 6),
                      Flexible(
                        child: Text(
                          'Alarm naar 3 gezinsleden',
                          style: text.labelMedium,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _MiniAvatar extends StatelessWidget {
  const _MiniAvatar({required this.letter, required this.color});

  final String letter;
  final Color color;

  @override
  Widget build(BuildContext context) => DecoratedBox(
    decoration: BoxDecoration(
      color: color,
      shape: BoxShape.circle,
      border: Border.all(color: Colors.white, width: 2),
    ),
    child: Center(
      child: Text(
        letter,
        style: Theme.of(context).textTheme.labelSmall
            ?.copyWith(color: Colors.white, fontSize: 9, letterSpacing: 0),
      ),
    ),
  );
}

/// Voortgangsring rond de noodknop.
class _HoldRingPainter extends CustomPainter {
  const _HoldRingPainter({required this.progress});

  final double progress;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = (Offset.zero & size).deflate(6);
    Paint stroke(Color c) => Paint()
      ..color = c
      ..style = PaintingStyle.stroke
      ..strokeWidth = 12
      ..strokeCap = StrokeCap.round;
    canvas
      ..drawArc(rect, 0, 2 * math.pi, false, stroke(AppColors.alert.withValues(alpha: .15)))
      ..drawArc(rect, -math.pi / 2, 2 * math.pi * progress, false, stroke(AppColors.alert));
  }

  @override
  bool shouldRepaint(_HoldRingPainter oldDelegate) => oldDelegate.progress != progress;
}
