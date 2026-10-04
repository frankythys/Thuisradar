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

    return Column(
      children: [
        MemberAvatar(
          member: member,
          size: 80,
          statusColor: location == null ? null : AppColors.primary,
        ),
        SizedBox(height: tokens.spaceMd),
        Text(
          member.displayName,
          style: text.headlineLarge,
          textAlign: TextAlign.center,
        ),
        SizedBox(height: tokens.spaceSm),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
          decoration: const ShapeDecoration(
            color: AppColors.primarySoft,
            shape: StadiumBorder(),
          ),
          child: Text(
            location == null ? 'Nog geen locatie' : trip.label,
            style: text.labelLarge?.copyWith(color: AppColors.primary),
          ),
        ),
        if (location != null) ...[
          SizedBox(height: tokens.spaceSm),
          Text(
            trip.description(location, now),
            style: text.bodyMedium?.copyWith(color: AppColors.muted),
            textAlign: TextAlign.center,
          ),
        ],
      ],
    );
  }
}
