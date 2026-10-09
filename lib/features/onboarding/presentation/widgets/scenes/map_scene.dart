import 'package:flutter/material.dart';

import '../../../../../core/theme/app_colors.dart';
import 'scene_bits.dart';

/// Stukje kaart met gezinsleden, een thuiszone en een live-melding.
class MapScene extends StatelessWidget {
  const MapScene({super.key});

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Stack(
      children: [
        const Positioned.fill(child: CustomPaint(painter: _StreetsPainter())),
        SceneDot(
          x: 190,
          y: 78,
          size: 96,
          child: DecoratedBox(
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: AppColors.primary.withValues(alpha: .12),
              border: Border.all(color: AppColors.primary.withValues(alpha: .45), width: 1.5),
            ),
          ),
        ),
        const SceneDot(x: 190, y: 78, size: 30, child: _PlaceTile(icon: Icons.home_rounded)),
        const SceneDot(x: 66, y: 42, size: 30, child: _PlaceTile(icon: Icons.school_rounded)),
        SceneDot(
          x: 222,
          y: 52,
          size: 40,
          child: SceneAvatar(letter: 'P', color: AppColors.forMemberIndex(0), online: true),
        ),
        SceneDot(
          x: 156,
          y: 104,
          size: 34,
          child: SceneAvatar(letter: 'M', color: AppColors.forMemberIndex(4)),
        ),
        SceneDot(
          x: 122,
          y: 138,
          size: 40,
          child: SceneAvatar(letter: 'L', color: AppColors.forMemberIndex(2), online: true),
        ),
        Positioned(
          left: 12,
          right: 12,
          bottom: 12,
          child: Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              boxShadow: sceneShadow,
            ),
            child: Row(
              children: [
                const SizedBox.square(
                  dimension: 32,
                  child: SceneTile(
                    icon: Icons.place_outlined,
                    color: AppColors.primary,
                    background: AppColors.primarySoft,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Liam is onderweg naar huis', style: text.labelLarge),
                      Text('Nog 6 min · 1,2 km', style: text.bodySmall?.copyWith(color: AppColors.muted)),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _PlaceTile extends StatelessWidget {
  const _PlaceTile({required this.icon});

  final IconData icon;

  @override
  Widget build(BuildContext context) => DecoratedBox(
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(10),
      boxShadow: sceneShadow,
    ),
    child: Icon(icon, size: 17, color: AppColors.primary),
  );
}

/// Eenvoudige straten op een lichte ondergrond.
class _StreetsPainter extends CustomPainter {
  const _StreetsPainter();

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawRect(Offset.zero & size, Paint()..color = const Color(0xFFE9EFF1));
    final block = Paint()..color = const Color(0xFFDCEBEF);
    canvas
      ..drawRRect(RRect.fromLTRBR(168, 10, 268, 74, const Radius.circular(14)), block)
      ..drawRRect(RRect.fromLTRBR(14, 150, 84, 204, const Radius.circular(12)), block);

    final main1 = Path()
      ..moveTo(-10, 112)
      ..cubicTo(70, 102, 150, 150, 290, 130);
    final main2 = Path()
      ..moveTo(116, -10)
      ..cubicTo(108, 84, 150, 186, 126, 280);
    Paint road(Color c, double w) => Paint()
      ..color = c
      ..style = PaintingStyle.stroke
      ..strokeWidth = w;
    for (final p in [main1, main2]) {
      canvas
        ..drawPath(p, road(const Color(0xFFD3E0E4), 17))
        ..drawPath(p, road(Colors.white, 12));
    }
    final minor = road(Colors.white, 5);
    canvas
      ..drawLine(const Offset(-10, 214), const Offset(290, 192), minor)
      ..drawLine(const Offset(40, -10), const Offset(56, 280), minor)
      ..drawLine(const Offset(222, -10), const Offset(238, 280), minor)
      ..drawLine(const Offset(-10, 24), const Offset(290, 40), minor);

    // Gestippeld spoor van Liam.
    final trail = Paint()
      ..color = AppColors.primary.withValues(alpha: .7)
      ..strokeWidth = 3
      ..strokeCap = StrokeCap.round;
    for (var t = 0.0; t <= 1; t += .09) {
      final p = Offset.lerp(const Offset(60, 214), const Offset(118, 144), t)!;
      canvas.drawCircle(p, 1.6, trail);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
