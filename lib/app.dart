import 'package:flutter/material.dart';

import 'core/push/push_gate.dart';
import 'core/theme/app_theme.dart';
import 'features/auth/presentation/auth_gate.dart';
import 'features/auth/presentation/app_pin_lock.dart';
import 'features/onboarding/presentation/onboarding_gate.dart';

class ThuisradarApp extends StatelessWidget {
  const ThuisradarApp({super.key});

  static final _navigatorKey = GlobalKey<NavigatorState>();

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      navigatorKey: _navigatorKey,
      title: 'CircleBeacon',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light(),
      builder: (context, child) => AppPinLock(
        onSignedOut: () => _navigatorKey.currentState?.popUntil((route) => route.isFirst),
        child: child!,
      ),
      home: const PushGate(child: OnboardingGate(child: AuthGate())),
    );
  }
}
