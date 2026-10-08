import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../application/onboarding_providers.dart';
import 'onboarding_screen.dart';
import 'intro_screen.dart';

/// Elke appstart toont de intro totdat de onboarding volledig is afgerond.
class OnboardingGate extends ConsumerStatefulWidget {
  const OnboardingGate({super.key, required this.child});

  final Widget child;

  @override
  ConsumerState<OnboardingGate> createState() => _OnboardingGateState();
}

class _OnboardingGateState extends ConsumerState<OnboardingGate> {
  bool _introFinished = false;

  void _finishIntro() {
    // Alleen voor deze sessie. Na herstart begint de intro opnieuw.
    setState(() => _introFinished = true);
  }

  @override
  Widget build(BuildContext context) {
    return ref
        .watch(onboardingSeenProvider)
        .when(
          data: (seen) {
            if (seen) return widget.child;
            if (_introFinished) return const OnboardingScreen();
            return IntroScreen(onFinished: _finishIntro);
          },
          loading: () =>
              const Scaffold(body: Center(child: CircularProgressIndicator())),
          // Bij twijfel de app gewoon tonen; onboarding is niet kritiek.
          error: (_, _) => widget.child,
        );
  }
}
