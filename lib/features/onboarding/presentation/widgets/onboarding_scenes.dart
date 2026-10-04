import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';

class RadarRings extends StatelessWidget {
  const RadarRings({super.key});
  @override
  Widget build(BuildContext context) => Stack(
    alignment: Alignment.center,
    children: [
      for (final diameter in [288.0, 256.0, 192.0, 144.0])
        Container(
          width: diameter,
          height: diameter,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: AppColors.primarySoft.withValues(alpha: .45),
          ),
        ),
    ],
  );
}

class HomeScene extends StatelessWidget {
  const HomeScene({super.key});
  @override
  Widget build(BuildContext context) => Stack(
    alignment: Alignment.center,
    children: [
      const RadarRings(),
      Container(
        width: 112,
        height: 112,
        decoration: _card(),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: AppColors.surfaceLow,
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(
                Icons.cottage_outlined,
                size: 28,
                color: AppColors.primary,
              ),
            ),
            const SizedBox(height: 6),
            const Text(
              'THUIS',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: AppColors.primary,
              ),
            ),
          ],
        ),
      ),
      const Positioned(
        top: 16,
        left: 24,
        child: _Pin('M', 'Mama', AppColors.primaryContainer),
      ),
      const Positioned(
        top: 32,
        right: 24,
        child: _Pin('P', 'Papa', Color(0xFF7C5BE8)),
      ),
      const Positioned(
        bottom: 6,
        child: _Pin('L', 'Lucas · Onderweg', Color(0xFF4B26B3), below: true),
      ),
    ],
  );
}

class _Pin extends StatelessWidget {
  const _Pin(this.initial, this.name, this.color, {this.below = false});
  final String initial, name;
  final Color color;
  final bool below;
  @override
  Widget build(BuildContext context) {
    final label = Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
      decoration: _card(20),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            below ? Icons.directions_bike : Icons.circle,
            size: below ? 12 : 6,
            color: color,
          ),
          const SizedBox(width: 4),
          Text(
            name,
            style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (!below) label,
        const SizedBox(height: 6),
        Container(
          width: 54,
          height: 54,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: color,
            border: Border.all(color: Colors.white, width: 4),
          ),
          child: Text(
            initial,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 20,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
        const SizedBox(height: 6),
        if (below)
          label
        else
          Container(width: 4, height: 12, color: color.withValues(alpha: .3)),
      ],
    );
  }
}

class NotificationScene extends StatelessWidget {
  const NotificationScene({super.key});
  @override
  Widget build(BuildContext context) => Stack(
    alignment: Alignment.center,
    children: [
      const RadarRings(),
      const Positioned(
        top: 26,
        left: 2,
        child: _SceneChip(Icons.home, 'Thuis'),
      ),
      const Positioned(
        top: 40,
        right: 0,
        child: _SceneChip(Icons.school, 'School'),
      ),
      Container(
        width: 238,
        height: 302,
        padding: const EdgeInsets.all(14),
        decoration: _card(22),
        child: Column(
          children: [
            Container(
              width: 56,
              height: 4,
              decoration: BoxDecoration(
                color: AppColors.primarySoft,
                borderRadius: BorderRadius.circular(4),
              ),
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(13),
              decoration: BoxDecoration(
                color: AppColors.surfaceLow,
                borderRadius: BorderRadius.circular(14),
                boxShadow: const [
                  BoxShadow(
                    color: Color(0x18005445),
                    blurRadius: 6,
                    offset: Offset(0, 3),
                  ),
                ],
              ),
              child: const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.home, color: AppColors.primary, size: 20),
                      SizedBox(width: 6),
                      Flexible(child: FittedBox(fit: BoxFit.scaleDown, child: Text(
                        'Thuisradar · Zojuist',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                        ),
                      ))),
                      Spacer(),
                      Icon(Icons.circle, size: 6, color: AppColors.primary),
                    ],
                  ),
                  SizedBox(height: 12),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      CircleAvatar(
                        radius: 16,
                        backgroundColor: Color(0xFF7C5BE8),
                        child: Text('L', style: TextStyle(color: Colors.white)),
                      ),
                      SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Lucas',
                              style: TextStyle(fontWeight: FontWeight.w700),
                            ),
                            Text(
                              'Veilig aangekomen op School',
                              style: TextStyle(fontSize: 12),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            for (final width in [168.0, 112.0])
              Align(
                alignment: Alignment.centerLeft,
                child: Container(
                  width: width,
                  height: 7,
                  margin: const EdgeInsets.only(bottom: 8),
                  color: AppColors.surfaceLow,
                ),
              ),
            const Spacer(),
            const Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.lock_outline, size: 11),
                SizedBox(width: 4),
                Flexible(child: FittedBox(fit: BoxFit.scaleDown, child: Text(
                  'Versleutelde gezinsradar',
                  style: TextStyle(fontSize: 10),
                ))),
              ],
            ),
          ],
        ),
      ),
    ],
  );
}

class EmergencyScene extends StatelessWidget {
  const EmergencyScene({super.key});
  @override
  Widget build(BuildContext context) => Container(
    margin: const EdgeInsets.all(6),
    decoration: _card(28),
    child: Stack(
      alignment: Alignment.center,
      children: [
        for (final size in [174.0, 146.0])
          Container(
            width: size,
            height: size,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: AppColors.alertSoft.withValues(alpha: .5),
            ),
          ),
        Container(
          width: 110,
          height: 110,
          decoration: const BoxDecoration(
            shape: BoxShape.circle,
            color: Color(0xFFA04700),
          ),
          child: const Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.warning_amber_rounded, color: Colors.white),
              SizedBox(height: 6),
              Text(
                'NOOD',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 2,
                ),
              ),
            ],
          ),
        ),
        const Positioned(top: 22, left: 26, child: _Relative('MA', 'Mama')),
        const Positioned(top: 22, right: 26, child: _Relative('PA', 'Papa')),
        const Positioned(bottom: 48, child: _Relative('LU', 'Lucas')),
        const Positioned(
          top: 42,
          child: _SceneChip(Icons.graphic_eq, 'Live verbonden'),
        ),
        const Positioned(
          bottom: 14,
          child: _SceneChip(
            Icons.shield_outlined,
            'Direct bericht naar alle 3 gezinsleden',
          ),
        ),
      ],
    ),
  );
}

class _Relative extends StatelessWidget {
  const _Relative(this.initials, this.name);
  final String initials, name;
  @override
  Widget build(BuildContext context) => Column(
    children: [
      CircleAvatar(
        radius: 23,
        backgroundColor: AppColors.primarySoft,
        child: Text(
          initials,
          style: const TextStyle(
            fontSize: 11,
            color: AppColors.primary,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
      const SizedBox(height: 5),
      Text(name, style: const TextStyle(fontSize: 11)),
    ],
  );
}

class _SceneChip extends StatelessWidget {
  const _SceneChip(this.icon, this.text);
  final IconData icon;
  final String text;
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
    decoration: BoxDecoration(
      color: AppColors.surfaceLow,
      borderRadius: BorderRadius.circular(24),
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 12, color: AppColors.primary),
        const SizedBox(width: 5),
        Text(
          text,
          style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w600),
        ),
      ],
    ),
  );
}

BoxDecoration _card([double radius = 20]) => BoxDecoration(
  color: Colors.white,
  borderRadius: BorderRadius.circular(radius),
  boxShadow: const [
    BoxShadow(color: Color(0x12005445), blurRadius: 18, offset: Offset(0, 6)),
  ],
);
