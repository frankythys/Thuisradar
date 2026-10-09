import 'package:flutter/material.dart';

import '../../../../../core/theme/app_colors.dart';
import 'scene_bits.dart';

/// Drie meldingen die na elkaar binnenschuiven, zoals op het vergrendelscherm.
class AlertsScene extends AnimatedScene {
  const AlertsScene({super.key, required super.progress});

  @override
  Widget build(BuildContext context) {
    final notes = [
      const _Note(
        icon: Icons.school_rounded,
        color: AppColors.primary,
        time: '08:12',
        message: 'Liam is op School',
      ),
      _Note(
        icon: Icons.work_rounded,
        color: AppColors.forMemberIndex(4),
        time: '17:04',
        message: 'Mama vertrekt van Werk',
      ),
      _Note(
        icon: Icons.home_rounded,
        color: AppColors.forMemberIndex(0),
        time: '17:31',
        message: 'Papa is thuis',
      ),
    ];
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          for (final (i, note) in notes.indexed) ...[
            if (i > 0) const SizedBox(height: 10),
            Builder(
              builder: (context) {
                final v = phase(t, i * .25, .35 + i * .25, Curves.easeOutBack);
                return Padding(
                  padding: EdgeInsets.symmetric(horizontal: i * 9.0),
                  child: Opacity(
                    opacity: v.clamp(0.0, 1.0) * (1 - i * .1),
                    child: Transform.translate(offset: Offset(0, -24 * (1 - v)), child: note),
                  ),
                );
              },
            ),
          ],
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
