import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_tokens.dart';
import '../../domain/onboarding_slide.dart';
import 'scenes/alerts_scene.dart';
import 'scenes/map_scene.dart';
import 'scenes/privacy_scene.dart';
import 'scenes/sos_scene.dart';
import 'scenes/scene_bits.dart';

/// Afgeronde illustratievlak bovenaan een slide; schaalt mee met het scherm.
class OnboardingStage extends StatelessWidget {
  const OnboardingStage({super.key, required this.scene});

  final OnboardingScene scene;

  @override
  Widget build(BuildContext context) {
    final radius = BorderRadius.circular(context.tokens.radiusSheet);
    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: radius,
        gradient: const RadialGradient(
          center: Alignment.topCenter,
          radius: 1.3,
          colors: [Colors.white, AppColors.primarySoft],
        ),
      ),
      child: ClipRRect(
        borderRadius: radius,
        child: FittedBox(
          // De kaart vult het vlak; de andere scènes blijven volledig zichtbaar.
          fit: scene == OnboardingScene.map ? BoxFit.cover : BoxFit.contain,
          child: SizedBox.fromSize(
            size: sceneSize,
            child: switch (scene) {
              OnboardingScene.map => const MapScene(),
              OnboardingScene.privacy => const PrivacyScene(),
              OnboardingScene.alerts => const AlertsScene(),
              OnboardingScene.sos => const SosScene(),
            },
          ),
        ),
      ),
    );
  }
}
