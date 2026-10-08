import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/onboarding_store.dart';

final onboardingStoreProvider = Provider<OnboardingStore>(
  (ref) => OnboardingStore(),
);

/// Of de onboarding al gezien is. De gate herlaadt dit na het afronden.
final onboardingSeenProvider = FutureProvider<bool>(
  (ref) => ref.watch(onboardingStoreProvider).hasSeen(),
);
