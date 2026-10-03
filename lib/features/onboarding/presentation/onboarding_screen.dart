import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_tokens.dart';
import '../application/onboarding_providers.dart';
import '../domain/onboarding_slide.dart';
import 'widgets/onboarding_hero.dart';

/// Toont de intro-slides; enkel de eerste keer (zie onboarding-gate).
class OnboardingScreen extends ConsumerStatefulWidget {
  const OnboardingScreen({super.key});

  @override
  ConsumerState<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends ConsumerState<OnboardingScreen> {
  final _controller = PageController();
  int _index = 0;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  bool get _isLast => _index == onboardingSlides.length - 1;

  Future<void> _finish() async {
    await ref.read(onboardingStoreProvider).markSeen();
    ref.invalidate(onboardingSeenProvider);
  }

  void _next() {
    if (_isLast) {
      _finish();
    } else {
      _controller.nextPage(duration: const Duration(milliseconds: 280), curve: Curves.easeOut);
    }
  }

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;

    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: EdgeInsets.all(tokens.spaceMd),
          child: Column(
            children: [
              Align(
                alignment: Alignment.centerRight,
                child: TextButton(onPressed: _finish, child: const Text('Overslaan')),
              ),
              Expanded(
                child: PageView.builder(
                  controller: _controller,
                  itemCount: onboardingSlides.length,
                  onPageChanged: (i) => setState(() => _index = i),
                  itemBuilder: (context, i) => _SlideView(slide: onboardingSlides[i]),
                ),
              ),
              SizedBox(height: tokens.spaceMd),
              _Dots(count: onboardingSlides.length, index: _index),
              SizedBox(height: tokens.spaceLg),
              FilledButton(
                onPressed: _next,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(_isLast ? 'Aan de slag' : 'Volgende'),
                    SizedBox(width: tokens.spaceSm),
                    const Icon(Icons.arrow_forward, size: 20),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SlideView extends StatelessWidget {
  const _SlideView({required this.slide});

  final OnboardingSlide slide;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final tokens = context.tokens;

    return SingleChildScrollView(
      child: Column(
        children: [
          SizedBox(height: tokens.spaceLg),
          OnboardingHero(icon: slide.icon),
          SizedBox(height: tokens.spaceXl),
          Text(slide.title, style: text.headlineLarge, textAlign: TextAlign.center),
          SizedBox(height: tokens.spaceMd),
          Text(
            slide.body,
            style: text.bodyLarge?.copyWith(color: AppColors.muted),
            textAlign: TextAlign.center,
          ),
          if (slide.footnote != null) ...[
            SizedBox(height: tokens.spaceXl),
            _Footnote(title: slide.footnoteTitle!, body: slide.footnote!),
          ],
        ],
      ),
    );
  }
}

class _Footnote extends StatelessWidget {
  const _Footnote({required this.title, required this.body});

  final String title;
  final String body;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final tokens = context.tokens;

    return Container(
      padding: EdgeInsets.all(tokens.spaceMd),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(tokens.radiusCard),
        boxShadow: tokens.shadowLevel1,
      ),
      child: Row(
        children: [
          const Icon(Icons.shield_rounded, color: AppColors.primary),
          SizedBox(width: tokens.spaceMd),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: text.titleMedium),
                SizedBox(height: tokens.spaceXs),
                Text(body, style: text.bodyMedium?.copyWith(color: AppColors.muted)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Dots extends StatelessWidget {
  const _Dots({required this.count, required this.index});

  final int count;
  final int index;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        for (var i = 0; i < count; i++)
          AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            margin: const EdgeInsets.symmetric(horizontal: 3),
            width: i == index ? 24 : 8,
            height: 8,
            decoration: BoxDecoration(
              color: i == index ? AppColors.primary : AppColors.border,
              borderRadius: BorderRadius.circular(4),
            ),
          ),
      ],
    );
  }
}
