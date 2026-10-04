import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';

/// Het huis met radarringen uit het aangeleverde Thuisradar-beeldmerk.
class RadarLogo extends StatelessWidget {
  const RadarLogo({super.key, this.size = 40});
  final double size;

  @override
  Widget build(BuildContext context) => Semantics(
    label: 'Thuisradar',
    image: true,
    child: Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: AppColors.primaryContainer,
        borderRadius: BorderRadius.circular(size * .27),
      ),
      child: CustomPaint(painter: _LogoPainter()),
    ),
  );
}

class _LogoPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    canvas.scale(size.width / 100, size.height / 100);
    final ring = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.5
      ..color = const Color(0xFF73B5A8);
    canvas.drawCircle(const Offset(50, 50), 35, ring);
    canvas.drawCircle(const Offset(50, 50), 25, ring);
    final house = Path()
      ..moveTo(30, 45)
      ..lineTo(50, 29)
      ..lineTo(70, 45)
      ..lineTo(70, 73)
      ..lineTo(56, 73)
      ..lineTo(56, 58)
      ..quadraticBezierTo(50, 52, 44, 58)
      ..lineTo(44, 73)
      ..lineTo(30, 73)
      ..close();
    canvas.drawPath(house, Paint()..color = Colors.white);
    canvas.drawCircle(
      const Offset(50, 46),
      4.5,
      Paint()..color = AppColors.primaryContainer,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
