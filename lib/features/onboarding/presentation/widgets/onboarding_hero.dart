import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../../../../core/theme/app_colors.dart';

const _heroSize = 220.0;

/// Toont de echte Stitch-illustratie bij [base] (`.png` of `.svg`). Ontbreekt die,
/// dan valt hij terug op een rustige radar-cirkel met [icon].
class OnboardingHero extends StatelessWidget {
  const OnboardingHero({super.key, required this.base, required this.icon});

  final String base;
  final IconData icon;

  /// Zoekt de eerste bestaande variant van de illustratie, of null.
  Future<String?> _resolve() async {
    for (final ext in const ['.svg', '.png']) {
      final path = '$base$ext';
      try {
        await rootBundle.load(path);
        return path;
      } on FlutterError {
        // Niet gebundeld: volgende extensie proberen.
      }
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: _heroSize,
      height: _heroSize,
      child: FutureBuilder<String?>(
        future: _resolve(),
        builder: (context, snapshot) {
          final path = snapshot.data;
          if (path == null) return _RadarFallback(icon: icon);
          if (path.endsWith('.svg')) {
            return SvgPicture.asset(path, fit: BoxFit.contain);
          }
          return Image.asset(
            path,
            fit: BoxFit.contain,
            errorBuilder: (_, _, _) => _RadarFallback(icon: icon),
          );
        },
      ),
    );
  }
}

class _RadarFallback extends StatelessWidget {
  const _RadarFallback({required this.icon});

  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Stack(
      alignment: Alignment.center,
      children: [
        _ring(_heroSize, 0.25),
        _ring(150, 0.45),
        _ring(104, 1),
        Icon(icon, size: 48, color: Colors.white),
      ],
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
