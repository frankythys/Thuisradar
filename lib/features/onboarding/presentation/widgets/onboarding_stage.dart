import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_tokens.dart';
import '../../domain/onboarding_slide.dart';
import 'scenes/alerts_scene.dart';
import 'scenes/map_scene.dart';
import 'scenes/privacy_scene.dart';
import 'scenes/scene_bits.dart';
import 'scenes/sos_scene.dart';

/// Afgeronde illustratievlak bovenaan een slide. De scène speelt één keer af
/// zodra de slide in beeld komt ([active]) en blijft dan op het eindbeeld staan.
class OnboardingStage extends StatefulWidget {
  const OnboardingStage({super.key, required this.scene, required this.active});

  final OnboardingScene scene;
  final bool active;

  @override
  State<OnboardingStage> createState() => _OnboardingStageState();
}

class _OnboardingStageState extends State<OnboardingStage> with SingleTickerProviderStateMixin {
  late final _controller = AnimationController(
    vsync: this,
    duration: widget.scene == OnboardingScene.map
        ? const Duration(milliseconds: 5200)
        : const Duration(milliseconds: 2600),
  );

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (widget.active && _controller.isDismissed) _play();
  }

  @override
  void didUpdateWidget(OnboardingStage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.active && !oldWidget.active) _play();
  }

  void _play() {
    // Animaties uit in de toegankelijkheidsinstellingen: meteen het eindbeeld.
    if (MediaQuery.of(context).disableAnimations) {
      _controller.value = 1;
    } else {
      _controller.forward(from: 0);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

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
          fit: widget.scene == OnboardingScene.map ? BoxFit.cover : BoxFit.contain,
          child: SizedBox.fromSize(
            size: sceneSize,
            child: switch (widget.scene) {
              OnboardingScene.map => MapScene(progress: _controller),
              OnboardingScene.privacy => PrivacyScene(progress: _controller),
              OnboardingScene.alerts => AlertsScene(progress: _controller),
              OnboardingScene.sos => SosScene(progress: _controller),
            },
          ),
        ),
      ),
    );
  }
}
