import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_colors.dart';
import '../../features/auth/application/auth_providers.dart';
import '../../features/family/application/family_providers.dart';
import '../../features/profile/presentation/profile_screen.dart';
import 'member_avatar.dart';

/// Je eigen avatar rechtsboven in de app-balk; opent je profiel. Zolang je
/// gezin of profiel nog laadt, staat er een neutraal profiel-icoon.
class ProfileAction extends ConsumerWidget {
  const ProfileAction({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final family = ref.watch(myFamilyProvider).value;
    final myId = ref.watch(currentUserIdProvider);
    final members = family == null ? null : ref.watch(familyMembersProvider(family.id)).value;
    final me = members?.where((m) => m.userId == myId).firstOrNull;

    return IconButton(
      tooltip: 'Profiel',
      icon: me == null
          ? const Icon(Icons.account_circle, color: AppColors.primary)
          : MemberAvatar(member: me, size: 32),
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
          await Navigator.of(context)
              .push(MaterialPageRoute<void>(builder: (_) => ProfileScreen(family: family)));
        } catch (_) {
          if (context.mounted) {
            ScaffoldMessenger.of(context)
                .showSnackBar(const SnackBar(content: Text('Profiel laden mislukt. Probeer opnieuw.')));
          }
        }
      },
    );
  }
}
