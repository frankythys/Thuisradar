import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../shared/widgets/app_card.dart';
import '../../domain/member_on_map.dart';
import '../../../../l10n/l10n.dart';

class OfflineMembers extends StatelessWidget {
  const OfflineMembers({super.key, required this.members, required this.onDetails});
  final List<MemberOnMap> members;
  final ValueChanged<MemberOnMap> onDetails;
  @override
  Widget build(BuildContext context) => AppCard(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(context.l10n.mapOfflineFamily(members.length), style: Theme.of(context).textTheme.titleMedium),
        Text(context.l10n.mapOfflineHint, style: TextStyle(fontSize: 11, color: AppColors.muted)),
        const SizedBox(height: 12),
        Row(
          children: [
            for (final entry in members.take(4))
              Expanded(
                child: InkWell(
                  onTap: () => onDetails(entry),
                  child: Container(
                    margin: const EdgeInsets.symmetric(horizontal: 4),
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: AppColors.surfaceLow,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Column(
                      children: [
                        CircleAvatar(
                          radius: 18,
                          backgroundColor: Colors.transparent,
                          child: Text(entry.member.initial, style: const TextStyle(color: AppColors.muted)),
                        ),
                        Text(
                          entry.member.displayName,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontSize: 11),
                        ),
                        Text(
                          context.l10n.mapNoSignal,
                          style: const TextStyle(fontSize: 10, color: AppColors.muted),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
          ],
        ),
        const SizedBox(height: 12),
        Text(context.l10n.mapPrivacyNote, style: const TextStyle(fontSize: 10, color: AppColors.muted)),
      ],
    ),
  );
}
