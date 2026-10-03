import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../application/onboarding_providers.dart';
import 'onboarding_screen.dart';

/// Toont de onboarding de eerste keer, daarna [child] (de rest van de app).
class OnboardingGate extends ConsumerWidget {
  const OnboardingGate({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return ref
        .watch(onboardingSeenProvider)
        .when(
          data: (seen) => seen ? child : const OnboardingScreen(),
          loading: () => const Scaffold(body: Center(child: CircularProgressIndicator())),
          // Bij twijfel de app gewoon tonen; onboarding is niet kritiek.
          error: (_, _) => child,
        );
  }
}
