import 'package:flutter/material.dart';

import '../../../../../core/theme/app_colors.dart';
import 'scene_bits.dart';

/// Schild in het midden van een besloten kring gezinsleden.
class PrivacyScene extends StatelessWidget {
  const PrivacyScene({super.key});

  @override
  Widget build(BuildContext context) {
    const cx = 140.0;
    const cy = 128.0;
    return Stack(
      clipBehavior: Clip.none,
      children: [
        SceneDot(
          x: cx,
          y: cy,
          size: 216,
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
          size: 150,
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
        SceneDot(
          x: 66,
          y: 84,
          size: 34,
          child: SceneAvatar(letter: 'P', color: AppColors.forMemberIndex(0)),
        ),
        SceneDot(
          x: 212,
          y: 80,
          size: 34,
          child: SceneAvatar(letter: 'M', color: AppColors.forMemberIndex(4)),
        ),
        SceneDot(
          x: 58,
          y: 178,
          size: 34,
          child: SceneAvatar(letter: 'L', color: AppColors.forMemberIndex(2)),
        ),
        SceneDot(
          x: 220,
          y: 182,
          size: 34,
          child: SceneAvatar(letter: 'E', color: AppColors.forMemberIndex(3)),
        ),
        const Positioned(
          top: 6,
          left: 8,
          right: 8,
          child: Center(
            child: ScenePill(icon: Icons.lock_outline_rounded, label: 'Versleuteld'),
          ),
        ),
        const Positioned(
          bottom: 4,
          left: 8,
          right: 8,
          child: Center(
            child: ScenePill(
              icon: Icons.block_rounded,
              label: 'Geen advertenties · nooit verkocht',
              muted: true,
            ),
          ),
        ),
      ],
    );
  }
}
