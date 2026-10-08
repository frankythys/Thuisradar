import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_colors.dart';
import '../../features/family/application/family_providers.dart';
import '../../features/profile/presentation/profile_screen.dart';

class ProfileAction extends ConsumerWidget {
  const ProfileAction({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) => IconButton(
    tooltip: 'Profiel',
    icon: const Icon(Icons.account_circle, color: AppColors.primary),
    onPressed: () async {
      try {
        final family = await ref.read(myFamilyProvider.future);
        if (!context.mounted) return;
        if (family == null) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Stel eerst je familie in om je gezinsprofiel te openen.')),
          );
          return;
        }
        Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => ProfileScreen(family: family)));
      } catch (_) {
        if (context.mounted) {
          ScaffoldMessenger.of(context)
              .showSnackBar(const SnackBar(content: Text('Profiel laden mislukt. Probeer opnieuw.')));
        }
      }
    },
  );
}
