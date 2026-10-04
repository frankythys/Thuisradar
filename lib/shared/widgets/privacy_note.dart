import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';

class PrivacyNote extends StatelessWidget {
  const PrivacyNote({super.key, required this.title, required this.body, this.icon = Icons.shield_outlined});
  final String title, body;
  final IconData icon;
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(color: AppColors.primarySoft, borderRadius: BorderRadius.circular(16)),
    child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Icon(icon, color: AppColors.primary, size: 22), const SizedBox(width: 12),
      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(title, style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 4),
        Text(body, style: Theme.of(context).textTheme.bodySmall?.copyWith(color: AppColors.muted)),
      ])),
    ]),
  );
}
