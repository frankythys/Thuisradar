part of 'welcome_screen.dart';

class _WelcomeHero extends StatelessWidget {
  const _WelcomeHero();

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 160,
      height: 160,
      child: Stack(
        alignment: Alignment.center,
        children: [
          _ring(160, 0.08),
          _ring(118, 0.16),
          const Positioned(
            top: 0,
            child: Chip(
              label: Text('• Actief', style: TextStyle(fontSize: 10)),
              visualDensity: VisualDensity.compact,
            ),
          ),
          const Positioned(
            bottom: 4,
            left: 100,
            child: CircleAvatar(
              radius: 12,
              backgroundColor: AppColors.primarySoft,
              child: Icon(Icons.person, size: 16, color: AppColors.primary),
            ),
          ),
          const Positioned(
            top: 24,
            right: 100,
            child: CircleAvatar(
              radius: 10,
              backgroundColor: Colors.white,
              child: Icon(Icons.check, size: 12, color: AppColors.primary),
            ),
          ),
          Container(
            width: 84,
            height: 84,
            decoration: const BoxDecoration(color: AppColors.primary, shape: BoxShape.circle),
            child: const Icon(Icons.home_rounded, color: Colors.white, size: 40),
          ),
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
