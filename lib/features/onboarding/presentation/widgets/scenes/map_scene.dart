import 'package:flutter/material.dart';

import '../../../../../core/theme/app_colors.dart';
import 'scene_bits.dart';

/// Liam rijdt over de kaart naar huis; de melding telt af en meldt de aankomst.
class MapScene extends AnimatedScene {
  const MapScene({super.key, required super.progress});

  /// Route van Liam: van School omlaag naar de grote weg, dan oostwaarts naar huis.
  static final Path route = Path()
    ..moveTo(50, 40)
    ..lineTo(51, 92)
    ..quadraticBezierTo(52, 106, 70, 105)
    ..quadraticBezierTo(128, 106, 184, 126);

  static const _home = Offset(190, 78);

  @override
  Widget build(BuildContext context) {
    final drive = phase(t, .08, .86, Curves.easeInOut);
    final arrived = t >= .88;
    final metric = route.computeMetrics().first;
    final tangent = metric.getTangentForOffset(metric.length * drive)!;
    final car = tangent.position;
    final pulse = phase(t, .86, 1);
    final liam = AppColors.forMemberIndex(2);

    return Stack(
      children: [
        Positioned.fill(
          child: CustomPaint(painter: _StreetsPainter(trail: metric.extractPath(0, metric.length * drive))),
        ),
        SceneDot(
          x: _home.dx,
          y: _home.dy,
          size: 96 + 14 * pulse * (1 - pulse) * 4,
          child: DecoratedBox(
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: AppColors.primary.withValues(alpha: .12 + .12 * pulse),
              border: Border.all(color: AppColors.primary.withValues(alpha: .45), width: 1.5),
            ),
          ),
        ),
        SceneDot(
          x: _home.dx,
          y: _home.dy,
          size: 30,
          child: const _PlaceTile(icon: Icons.home_rounded),
        ),
        const SceneDot(x: 76, y: 30, size: 30, child: _PlaceTile(icon: Icons.school_rounded)),
        SceneDot(
          x: 224,
          y: 50,
          size: 40,
          child: SceneAvatar(letter: 'P', color: AppColors.forMemberIndex(0), online: true),
        ),
        SceneDot(
          x: 238,
          y: 182,
          size: 34,
          child: SceneAvatar(letter: 'M', color: AppColors.forMemberIndex(4)),
        ),
        Positioned(
          left: car.dx - 22,
          top: car.dy - 17,
          width: 44,
          height: 34,
          child: _Car(color: liam),
        ),
        Positioned(
          left: 12,
          right: 12,
          bottom: 12 - 70 * (1 - phase(t, 0, .18)),
          child: _Toast(progress: drive, arrived: arrived),
        ),
      ],
    );
  }
}

/// Auto-marker met Liams letter, zoals op de echte kaart tijdens het rijden.
class _Car extends StatelessWidget {
  const _Car({required this.color});

  final Color color;

  @override
  Widget build(BuildContext context) {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        Positioned.fill(
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              boxShadow: sceneShadow,
            ),
            child: Icon(Icons.directions_car_rounded, size: 24, color: color),
          ),
        ),
        Positioned(
          right: -6,
          top: -6,
          child: Container(
            width: 18,
            height: 18,
            decoration: BoxDecoration(
              color: color,
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white, width: 2),
            ),
            child: Center(
              child: Text(
                'L',
                style: Theme.of(context).textTheme.labelSmall
                    ?.copyWith(color: Colors.white, fontSize: 9, letterSpacing: 0),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

/// Live-melding onderaan: aftellen tijdens de rit, aankomst op het einde.
class _Toast extends StatelessWidget {
  const _Toast({required this.progress, required this.arrived});

  final double progress;
  final bool arrived;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final minutes = (6 * (1 - progress)).ceil().clamp(1, 6);
    final km = (1.2 * (1 - progress)).clamp(.1, 1.2).toStringAsFixed(1).replaceAll('.', ',');
    final home = AppColors.forMemberIndex(0);
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: sceneShadow,
      ),
      child: Row(
        children: [
          SizedBox.square(
            dimension: 32,
            child: SceneTile(
              icon: arrived ? Icons.home_rounded : Icons.directions_car_rounded,
              color: arrived ? home : AppColors.primary,
              background: arrived ? home.withValues(alpha: .12) : AppColors.primarySoft,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 250),
              child: Column(
                key: ValueKey(arrived),
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    arrived ? 'Liam is thuis aangekomen' : 'Liam rijdt naar huis',
                    style: text.labelLarge,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  Text(
                    arrived ? 'Zojuist' : 'Nog $minutes min · $km km',
                    style: text.bodySmall?.copyWith(color: AppColors.muted),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
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

/// Straten op een lichte ondergrond, met het afgelegde spoor van Liam.
class _StreetsPainter extends CustomPainter {
  const _StreetsPainter({required this.trail});

  final Path trail;

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
      ..moveTo(122, -10)
      ..cubicTo(128, 84, 132, 186, 128, 280);
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

    // Afgelegde weg als stippellijn achter de auto.
    final dot = Paint()..color = AppColors.primary.withValues(alpha: .7);
    for (final metric in trail.computeMetrics()) {
      for (var d = 0.0; d < metric.length; d += 9) {
        canvas.drawCircle(metric.getTangentForOffset(d)!.position, 1.8, dot);
      }
    }
  }

  @override
  bool shouldRepaint(_StreetsPainter oldDelegate) => true;
}
