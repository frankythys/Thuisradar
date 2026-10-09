import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../application/onboarding_providers.dart';

/// Knop in het profiel om de introductie opnieuw te bekijken, zonder uit te loggen.
class ReplayOnboardingButton extends ConsumerWidget {
  const ReplayOnboardingButton({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return OutlinedButton.icon(
      onPressed: () async {
        await ref.read(onboardingStoreProvider).reset();
        ref.invalidate(onboardingSeenProvider);
        // De onboarding-gate zit onder de eerste route; sluit dus de bovenliggende schermen.
        if (context.mounted) Navigator.popUntil(context, (route) => route.isFirst);
      },
      icon: const Icon(Icons.replay_rounded),
      label: const Text('Introductie opnieuw bekijken'),
    );
  }
}
