import 'package:flutter/material.dart';

import 'core/theme/app_theme.dart';
import 'features/auth/presentation/auth_gate.dart';
import 'features/onboarding/presentation/onboarding_gate.dart';

class ThuisradarApp extends StatelessWidget {
  const ThuisradarApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Thuisradar',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light(),
      home: const OnboardingGate(child: AuthGate()),
    );
  }
}
