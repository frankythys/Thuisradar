import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_tokens.dart';
import '../../../../shared/widgets/radar_logo.dart';
import '../../domain/onboarding_slide.dart';

/// Merk links, "Overslaan" rechts (niet op de laatste slide).
class OnboardingTopBar extends StatelessWidget {
  const OnboardingTopBar({super.key, this.onSkip});

  final VoidCallback? onSkip;

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    return Padding(
      padding: EdgeInsets.fromLTRB(tokens.spaceLg, tokens.spaceSm, tokens.spaceSm, 0),
      child: SizedBox(
        height: 48,
        child: Row(
          children: [
            const RadarLogo(size: 28),
            SizedBox(width: tokens.spaceSm),
            Expanded(
              child: Text(
                'CircleBeacon',
                style: Theme.of(context).textTheme.titleMedium,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            if (onSkip != null)
              TextButton(
                onPressed: onSkip,
                style: TextButton.styleFrom(foregroundColor: AppColors.muted),
                child: const Text('Overslaan'),
              ),
          ],
        ),
      ),
    );
  }
}

/// Titelblok onder de illustratie: label, titel, uitleg en geruststelling.
class OnboardingCopy extends StatelessWidget {
  const OnboardingCopy({super.key, required this.slide});

  final OnboardingSlide slide;

  static const _reassuranceIcons = {
    OnboardingScene.map: Icons.battery_5_bar_rounded,
    OnboardingScene.privacy: Icons.lock_outline_rounded,
    OnboardingScene.alerts: Icons.notifications_none_rounded,
    OnboardingScene.sos: Icons.check_rounded,
  };

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final tokens = context.tokens;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          slide.eyebrow.toUpperCase(),
          style: text.labelSmall?.copyWith(color: AppColors.primary, letterSpacing: 1.3),
        ),
        SizedBox(height: tokens.spaceSm),
        Text(slide.title, style: text.headlineMedium),
        SizedBox(height: tokens.spaceSm),
        Text(slide.body, style: text.bodyMedium?.copyWith(color: AppColors.muted)),
        SizedBox(height: tokens.spaceMd),
        Row(
          children: [
            Container(
              width: 28,
              height: 28,
              decoration: const BoxDecoration(color: AppColors.primarySoft, shape: BoxShape.circle),
              child: Icon(_reassuranceIcons[slide.scene], size: 16, color: AppColors.primary),
            ),
            SizedBox(width: tokens.spaceSm),
            Expanded(child: Text(slide.reassurance, style: text.labelLarge)),
          ],
        ),
      ],
    );
  }
}

/// Voortgangsbalkjes; het actieve is langer.
class OnboardingProgress extends StatelessWidget {
  const OnboardingProgress({super.key, required this.count, required this.index});

  final int count;
  final int index;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: 'Stap ${index + 1} van $count',
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (var i = 0; i < count; i++)
            AnimatedContainer(
              duration: const Duration(milliseconds: 220),
              margin: EdgeInsets.only(right: i == count - 1 ? 0 : 6),
              width: i == index ? 26 : 8,
              height: 8,
              decoration: BoxDecoration(
                color: i == index ? AppColors.primary : AppColors.border,
                borderRadius: BorderRadius.circular(4),
              ),
            ),
        ],
      ),
    );
  }
}

/// Onderkant: voortgang + ronde pijl, of op de laatste slide de startknoppen.
class OnboardingFooter extends StatelessWidget {
  const OnboardingFooter({
    super.key,
    required this.count,
    required this.index,
    required this.onNext,
    required this.onHaveCode,
  });

  final int count;
  final int index;
  final VoidCallback onNext;
  final VoidCallback onHaveCode;

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    final isLast = index == count - 1;
    final progress = OnboardingProgress(count: count, index: index);

    if (!isLast) {
      return Padding(
        padding: EdgeInsets.fromLTRB(tokens.spaceLg, tokens.spaceSm, tokens.spaceLg, tokens.spaceLg),
        child: Row(
          children: [
            progress,
            const Spacer(),
            IconButton.filled(
              tooltip: 'Volgende',
              onPressed: onNext,
              style: IconButton.styleFrom(fixedSize: const Size.square(56)),
              icon: const Icon(Icons.arrow_forward_rounded),
            ),
          ],
        ),
      );
    }
    return Padding(
      padding: EdgeInsets.fromLTRB(tokens.spaceLg, tokens.spaceSm, tokens.spaceLg, tokens.spaceSm),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Center(child: progress),
          SizedBox(height: tokens.spaceMd),
          FilledButton(
            onPressed: onNext,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Text('Aan de slag'),
                SizedBox(width: tokens.spaceSm),
                const Icon(Icons.arrow_forward_rounded, size: 20),
              ],
            ),
          ),
          TextButton(onPressed: onHaveCode, child: const Text('Ik heb al een gezinscode')),
        ],
      ),
    );
  }
}
