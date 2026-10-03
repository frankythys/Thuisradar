import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';

/// Rustige hero: een icoon in concentrische teal-cirkels (radar-gevoel),
/// in de stijl van de mockups maar zonder zware illustraties.
class OnboardingHero extends StatelessWidget {
  const OnboardingHero({super.key, required this.icon});

  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 200,
      height: 200,
      child: Stack(
        alignment: Alignment.center,
        children: [
          _ring(200, 0.25),
          _ring(150, 0.45),
          _ring(104, 1),
          Icon(icon, size: 48, color: Colors.white),
        ],
      ),
    );
  }

  Widget _ring(double size, double opacity) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: Color.lerp(AppColors.ground, AppColors.primary, opacity),
      ),
    );
  }
}
