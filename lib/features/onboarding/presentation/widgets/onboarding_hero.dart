import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import 'onboarding_scenes.dart';

class OnboardingHero extends StatelessWidget {
  const OnboardingHero({super.key, required this.base, required this.icon});
  final String base;
  final IconData icon;
  @override
  Widget build(BuildContext context) => SizedBox(
    width: 340,
    height: 340,
    child: FittedBox(
      child: SizedBox(
        width: 340,
        height: 340,
        child: switch (base.split('_').last) {
          '2' => Stack(
            alignment: Alignment.center,
            children: [const RadarRings(), SvgPicture.asset('$base.svg', width: 240, height: 240)],
          ),
          '3' => const NotificationScene(),
          '4' => const EmergencyScene(),
          _ => const HomeScene(),
        },
      ),
    ),
  );
}
