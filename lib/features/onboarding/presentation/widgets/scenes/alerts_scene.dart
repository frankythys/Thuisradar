import 'package:flutter/material.dart';

import '../../../../../core/theme/app_colors.dart';
import 'scene_bits.dart';

/// Drie meldingen bij aankomst en vertrek, licht gestapeld.
class AlertsScene extends StatelessWidget {
  const AlertsScene({super.key});

  @override
  Widget build(BuildContext context) {
    final home = AppColors.forMemberIndex(0);
    final work = AppColors.forMemberIndex(4);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const _Note(
            icon: Icons.school_rounded,
            color: AppColors.primary,
            time: '08:12',
            message: 'Liam is op School',
          ),
          const SizedBox(height: 10),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: Opacity(
              opacity: .92,
              child: _Note(
                icon: Icons.work_rounded,
                color: work,
                time: '17:04',
                message: 'Mama vertrekt van Werk',
              ),
            ),
          ),
          const SizedBox(height: 10),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 18),
            child: Opacity(
              opacity: .8,
              child: _Note(icon: Icons.home_rounded, color: home, time: '17:31', message: 'Papa is thuis'),
            ),
          ),
        ],
      ),
    );
  }
}

class _Note extends StatelessWidget {
  const _Note({required this.icon, required this.color, required this.time, required this.message});

  final IconData icon;
  final Color color;
  final String time;
  final String message;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final meta = text.labelSmall?.copyWith(color: AppColors.muted, letterSpacing: 0);
    return Container(
      padding: const EdgeInsets.all(11),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        boxShadow: sceneShadow,
      ),
      child: Row(
        children: [
          SizedBox.square(
            dimension: 34,
            child: SceneTile(icon: icon, color: color, background: color.withValues(alpha: .12)),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text('CircleBeacon', style: meta, overflow: TextOverflow.ellipsis),
                    ),
                    Text(time, style: meta),
                  ],
                ),
                const SizedBox(height: 2),
                Text(message, style: text.labelLarge, maxLines: 1, overflow: TextOverflow.ellipsis),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
