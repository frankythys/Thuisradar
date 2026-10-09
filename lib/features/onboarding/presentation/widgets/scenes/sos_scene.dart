import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../../../core/theme/app_colors.dart';
import 'scene_bits.dart';

/// Noodknop die voor twee derde is ingedrukt, met wie het alarm krijgt.
class SosScene extends StatelessWidget {
  const SosScene({super.key});

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Stack(
      clipBehavior: Clip.none,
      children: [
        SceneDot(
          x: 140,
          y: 108,
          size: 196,
          child: DecoratedBox(
            decoration: BoxDecoration(shape: BoxShape.circle, color: AppColors.alert.withValues(alpha: .08)),
          ),
        ),
        const SceneDot(
          x: 140,
          y: 108,
          size: 160,
          child: CustomPaint(painter: _HoldRingPainter(progress: 2 / 3)),
        ),
        SceneDot(
          x: 140,
          y: 108,
          size: 136,
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
                Text('Houd 3 sec. vast', style: text.labelMedium?.copyWith(color: Colors.white)),
              ],
            ),
          ),
        ),
        Positioned(
          left: 8,
          right: 8,
          bottom: 8,
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
