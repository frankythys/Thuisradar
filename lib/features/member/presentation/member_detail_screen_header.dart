part of 'member_detail_screen.dart';

class _Header extends ConsumerWidget {
  const _Header({required this.member, required this.location});

  final FamilyMember member;
  final MemberLocation? location;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final text = Theme.of(context).textTheme;
    final tokens = context.tokens;
    final now = ref.watch(clockProvider).value ?? DateTime.now();
    final trip = TripStatus.at(location, now);

    // Compact: avatar links, naam en statusregel ernaast. Geen aparte
    // statuspil meer, zodat de vaste kop in het paneel laag blijft.
    return Row(
      children: [
        MemberAvatar(member: member, size: 56, statusColor: location == null ? null : AppColors.primary),
        SizedBox(width: tokens.spaceMd),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                member.displayName,
                style: text.headlineSmall,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              SizedBox(height: tokens.spaceXs),
              Text(
                location == null ? 'Nog geen locatie' : trip.description(location, now),
                style: text.bodyMedium?.copyWith(color: AppColors.muted),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ],
    );
  }
}
