import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_tokens.dart';
import '../../../shared/widgets/member_avatar.dart';
import '../../family/domain/family_member.dart';

/// Bovenaan het profiel: avatar in je kaartkleur, naam, rol + telefoon en
/// één knop "Bewerken" (naam, telefoon en kleur).
class ProfileHeader extends StatelessWidget {
  const ProfileHeader({super.key, required this.me, required this.onEdit});

  final FamilyMember? me;
  final VoidCallback onEdit;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final tokens = context.tokens;
    final member = me;
    final details = [
      if (member != null) member.isOwner ? 'Beheerder' : 'Gezinslid',
      if (member?.phone case final phone? when phone.isNotEmpty) phone,
    ].join(' · ');
    return Row(
      children: [
        if (member != null) MemberAvatar(member: member, size: 60),
        SizedBox(width: tokens.spaceMd),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                member?.displayName ?? 'Jouw profiel',
                style: text.headlineMedium,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              if (details.isNotEmpty) Text(details, style: text.bodySmall?.copyWith(color: AppColors.muted)),
            ],
          ),
        ),
        OutlinedButton.icon(
          onPressed: onEdit,
          style: OutlinedButton.styleFrom(minimumSize: const Size(0, 40)),
          icon: const Icon(Icons.edit_outlined, size: 18),
          label: const Text('Bewerken'),
        ),
      ],
    );
  }
}
