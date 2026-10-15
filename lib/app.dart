import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/push/push_gate.dart';
import 'core/theme/app_theme.dart';
import 'features/auth/presentation/auth_gate.dart';
import 'features/auth/presentation/app_pin_lock.dart';
import 'features/language/application/language_providers.dart';
import 'features/language/application/app_locale.dart';
import 'features/onboarding/presentation/onboarding_gate.dart';

class ThuisradarApp extends ConsumerWidget {
  const ThuisradarApp({super.key});

  static final _navigatorKey = GlobalKey<NavigatorState>();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final chosen = ref.watch(languageOverrideProvider);
    return MaterialApp(
      navigatorKey: _navigatorKey,
      title: 'CircleBeacon',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light(),
      // Eigen keuze uit Profiel, anders de toesteltaal (zie resolveAppLanguage).
      locale: AppLocale.of(chosen),
      supportedLocales: AppLocale.supported,
      localizationsDelegates: AppLocale.delegates,
      localeListResolutionCallback: AppLocale.resolve,
      builder: (context, child) => AppPinLock(
        onSignedOut: () => _navigatorKey.currentState?.popUntil((route) => route.isFirst),
        child: child!,
      ),
      home: const PushGate(child: OnboardingGate(child: AuthGate())),
    );
  }
}
