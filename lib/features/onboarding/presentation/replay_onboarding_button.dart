import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../profile/presentation/profile_tile.dart';
import '../application/onboarding_providers.dart';

/// Rij in het profiel om de introductie opnieuw te bekijken, zonder uit te loggen.
class ReplayOnboardingButton extends ConsumerWidget {
  const ReplayOnboardingButton({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return ProfileTile(
      icon: Icons.play_circle_outline,
      title: 'Introductie opnieuw bekijken',
      onTap: () async {
        await ref.read(onboardingStoreProvider).reset();
        ref.invalidate(onboardingSeenProvider);
        // De onboarding-gate zit onder de eerste route; sluit dus de bovenliggende schermen.
        if (context.mounted) Navigator.popUntil(context, (route) => route.isFirst);
      },
    );
  }
}
