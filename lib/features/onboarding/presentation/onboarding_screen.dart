import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_tokens.dart';
import '../application/onboarding_providers.dart';
import '../domain/onboarding_slide.dart';
import 'widgets/onboarding_parts.dart';
import 'widgets/onboarding_stage.dart';
import 'widgets/scenes/scene_bits.dart';

/// Toont de intro-slides; enkel de eerste keer (zie onboarding-gate).
class OnboardingScreen extends ConsumerStatefulWidget {
  const OnboardingScreen({super.key});

  @override
  ConsumerState<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends ConsumerState<OnboardingScreen> {
  final _controller = PageController();
  int _index = 0;

  static final _lastIndex = onboardingSlides.length - 1;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  bool get _isLast => _index == _lastIndex;

  Future<void> _finish() async {
    await ref.read(onboardingStoreProvider).markSeen();
    ref.invalidate(onboardingSeenProvider);
  }

  void _goTo(int page) {
    _controller.animateToPage(page, duration: const Duration(milliseconds: 320), curve: Curves.easeOutCubic);
  }

  void _next() => _isLast ? _finish() : _goTo(_index + 1);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            // Overslaan springt naar de laatste slide; afronden blijft een bewuste keuze.
            OnboardingTopBar(onSkip: _isLast ? null : () => _goTo(_lastIndex)),
            Expanded(
              child: PageView.builder(
                controller: _controller,
                itemCount: onboardingSlides.length,
                onPageChanged: (i) => setState(() => _index = i),
                itemBuilder: (context, i) => _SlidePage(slide: onboardingSlides[i]),
              ),
            ),
            OnboardingFooter(
              count: onboardingSlides.length,
              index: _index,
              onNext: _next,
              onHaveCode: _finish,
            ),
          ],
        ),
      ),
    );
  }
}

class _SlidePage extends StatelessWidget {
  const _SlidePage({required this.slide});

  final OnboardingSlide slide;

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: tokens.spaceMd),
      child: Column(
        children: [
          SizedBox(height: tokens.spaceXs),
          Expanded(
            // Vaste verhouding: op hoge schermen komt er lucht rond, niet een uitvergrote scène.
            child: Center(
              child: AspectRatio(
                aspectRatio: sceneAspectRatio,
                child: OnboardingStage(scene: slide.scene),
              ),
            ),
          ),
          Padding(
            padding: EdgeInsets.fromLTRB(tokens.spaceXs, tokens.spaceLg, tokens.spaceXs, 0),
            child: OnboardingCopy(slide: slide),
          ),
        ],
      ),
    );
  }
}
