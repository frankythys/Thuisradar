import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_tokens.dart';
import '../../../../shared/widgets/member_avatar.dart';
import '../../../family/domain/family_member.dart';

/// Eén regel met wie het alarm krijgt: overlappende avatars + namen.
class SosRecipients extends StatelessWidget {
  const SosRecipients({super.key, required this.members});

  final List<FamilyMember> members;

  static const _avatar = 32.0;
  static const _shown = 4;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final tokens = context.tokens;

    if (members.isEmpty) {
      return Text(
        'Nog niemand in je gezin om te waarschuwen.',
        style: text.bodyMedium?.copyWith(color: AppColors.muted),
        textAlign: TextAlign.center,
      );
    }

    final shown = members.take(_shown).toList();
    final step = _avatar * .7;
    final names = members.map((m) => m.displayName).join(', ');

    return Container(
      padding: EdgeInsets.symmetric(horizontal: tokens.spaceMd, vertical: tokens.spaceSm + tokens.spaceXs),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(tokens.radiusCard),
        boxShadow: tokens.shadowLevel1,
      ),
      child: Row(
        children: [
          SizedBox(
            width: _avatar + step * (shown.length - 1),
            height: _avatar,
            child: Stack(
              children: [
                for (var i = 0; i < shown.length; i++)
                  Positioned(
                    left: step * i,
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white, width: 2),
                      ),
                      child: MemberAvatar(member: shown[i], size: _avatar - 4),
                    ),
                  ),
              ],
            ),
          ),
          SizedBox(width: tokens.spaceSm + tokens.spaceXs),
          Expanded(
            child: Text.rich(
              TextSpan(
                children: [
                  TextSpan(
                    text: 'Krijgt alarm: ',
                    style: text.bodyMedium?.copyWith(color: AppColors.muted),
                  ),
                  TextSpan(text: names, style: text.titleMedium),
                ],
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}
