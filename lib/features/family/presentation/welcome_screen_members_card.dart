part of 'welcome_screen.dart';

class _MembersCard extends StatelessWidget {
  const _MembersCard({required this.members, required this.myId, required this.locations});

  final List<FamilyMember> members;
  final String? myId;
  final List<MemberLocation> locations;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final tokens = context.tokens;

    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text('Huidige gezinsleden', style: text.titleLarge),
              const Spacer(),
              _CountPill(count: members.length),
            ],
          ),
          SizedBox(height: tokens.spaceMd),
          for (final member in members) ...[
            Padding(
              padding: EdgeInsets.symmetric(vertical: tokens.spaceSm),
              child: Row(
                children: [
                  MemberAvatar(member: member, size: 48),
                  SizedBox(width: tokens.spaceMd),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(member.displayName, style: text.titleMedium),
                        Text(
                          member.userId == myId ? 'Jij' : (member.isOwner ? 'Beheerder' : 'Gezinslid'),
                          style: text.bodySmall?.copyWith(color: AppColors.muted),
                        ),
                      ],
                    ),
                  ),
                  BatteryBadge(level: locations.where((l) => l.userId == member.userId).firstOrNull?.battery),
                ],
              ),
            ),
          ],
          SizedBox(height: tokens.spaceSm),
          Container(
            padding: EdgeInsets.all(tokens.spaceMd),
            decoration: BoxDecoration(
              color: AppColors.ground,
              borderRadius: BorderRadius.circular(tokens.radiusInput),
            ),
            child: Row(
              children: [
                const Icon(Icons.lock_outline, size: 18, color: AppColors.muted),
                SizedBox(width: tokens.spaceMd),
                Expanded(
                  child: Text(
                    'Locaties worden enkel binnen deze kring gedeeld. Je gegevens blijven privé.',
                    style: text.bodyMedium?.copyWith(color: AppColors.muted),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
