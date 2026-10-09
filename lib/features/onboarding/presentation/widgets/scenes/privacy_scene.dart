import 'package:flutter/material.dart';

import '../../../../../core/theme/app_colors.dart';
import 'scene_bits.dart';

/// Schild in het midden van een besloten kring gezinsleden.
class PrivacyScene extends AnimatedScene {
  const PrivacyScene({super.key, required super.progress});

  @override
  Widget build(BuildContext context) {
    const cx = 140.0;
    const cy = 128.0;
    final rings = phase(t, 0, .45);
    final shield = phase(t, .05, .4, Curves.easeOutBack);
    final pills = phase(t, .7, 1);
    Widget member(int i, double x, double y, String letter, int colorIndex) {
      final v = phase(t, .3 + i * .1, .55 + i * .1, Curves.easeOutBack);
      return SceneDot(
        x: cx + (x - cx) * v,
        y: cy + (y - cy) * v,
        size: 34,
        child: Opacity(
          opacity: v.clamp(0, 1),
          child: SceneAvatar(letter: letter, color: AppColors.forMemberIndex(colorIndex)),
        ),
      );
    }

    return Stack(
      clipBehavior: Clip.none,
      children: [
        SceneDot(
          x: cx,
          y: cy,
          size: 216 * rings,
          child: DecoratedBox(
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.white.withValues(alpha: .55),
              border: Border.all(color: AppColors.primary.withValues(alpha: .14), width: 1.5),
            ),
          ),
        ),
        SceneDot(
          x: cx,
          y: cy,
          size: 150 * rings,
          child: DecoratedBox(
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: AppColors.primary.withValues(alpha: .25), width: 1.5),
            ),
          ),
        ),
        SceneDot(
          x: cx,
          y: cy,
          size: 84,
          child: Transform.scale(
            scale: shield,
            child: DecoratedBox(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(28),
                gradient: const LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [AppColors.primaryContainer, AppColors.primary],
                ),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.primary.withValues(alpha: .55),
                    blurRadius: 24,
                    spreadRadius: -10,
                    offset: const Offset(0, 14),
                  ),
                ],
              ),
              child: const Icon(Icons.verified_user_rounded, size: 42, color: Colors.white),
            ),
          ),
        ),
        member(0, 66, 84, 'P', 0),
        member(1, 212, 80, 'M', 4),
        member(2, 58, 178, 'L', 2),
        member(3, 220, 182, 'E', 3),
        Positioned(
          top: 6 - 10 * (1 - pills),
          left: 8,
          right: 8,
          child: Opacity(
            opacity: pills,
            child: const Center(
              child: ScenePill(icon: Icons.lock_outline_rounded, label: 'Versleuteld'),
            ),
          ),
        ),
        Positioned(
          bottom: 4 - 10 * (1 - pills),
          left: 8,
          right: 8,
          child: Opacity(
            opacity: pills,
            child: const Center(
              child: ScenePill(
                icon: Icons.block_rounded,
                label: 'Geen advertenties · nooit verkocht',
                muted: true,
              ),
            ),
          ),
        ),
      ],
    );
  }
}
