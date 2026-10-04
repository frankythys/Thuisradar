import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';

class PrivacyAction extends StatelessWidget {
  const PrivacyAction({super.key});
  @override
  Widget build(BuildContext context) => IconButton(
    tooltip: 'Privacy en beveiliging',
    icon: const Icon(Icons.shield_outlined, size: 20, color: AppColors.primary),
    onPressed: () => showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Alleen voor je gezin'),
        content: const Text(
          'Alleen leden van jouw gezinskring kunnen je gedeelde locaties en berichten bekijken. De verbinding met de server is versleuteld. Je kunt locatie delen pauzeren in je profiel.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Sluiten'),
          ),
        ],
      ),
    ),
  );
}
