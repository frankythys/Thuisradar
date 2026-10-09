part of 'chat_screen.dart';

class _Bubble extends StatelessWidget {
  const _Bubble({required this.message, required this.mine, this.name, this.sender});

  final Message message;
  final bool mine;
  final String? name;

  /// Afzender (enkel bij berichten van anderen): kleine avatar links.
  final FamilyMember? sender;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final tokens = context.tokens;

    final shared = Uri.tryParse(message.body);
    final coordinates = shared?.host == 'www.google.com' ? shared?.queryParameters['q']?.split(',') : null;
    final lat = coordinates?.length == 2 ? double.tryParse(coordinates![0]) : null;
    final lng = coordinates?.length == 2 ? double.tryParse(coordinates![1]) : null;
    final bubble = Container(
      margin: EdgeInsets.only(bottom: tokens.spaceSm),
      padding: EdgeInsets.symmetric(horizontal: tokens.spaceMd, vertical: tokens.spaceSm),
      constraints: BoxConstraints(maxWidth: MediaQuery.sizeOf(context).width * 0.75),
      decoration: BoxDecoration(
        color: mine ? AppColors.primary : Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(tokens.radiusInput),
        boxShadow: mine ? null : tokens.shadowLevel1,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (name != null)
            Text(
              name!,
              style: text.labelMedium?.copyWith(
                color: sender == null ? AppColors.primary : tokens.memberColor(sender!.colorIndex),
              ),
            ),
          if (Attachment.parse(message.body, message.familyId) case final attachment?)
            AttachmentView(attachment: attachment)
          else if (lat != null && lng != null) ...[
            LocationPreview(
              latitude: lat,
              longitude: lng,
              initial: name?.substring(0, 1) ?? 'J',
              height: 150,
            ),
            const SizedBox(height: 8),
            Text(
              'Gedeelde locatie',
              style: text.titleMedium?.copyWith(
                color: mine ? Theme.of(context).colorScheme.onPrimary : AppColors.ink,
              ),
            ),
            TextButton(
              onPressed: () => openDirections(context, lat, lng),
              child: const Text('Bekijk op kaart →'),
            ),
          ] else
            Text(
              message.body,
              style: text.bodyMedium?.copyWith(
                color: mine ? Theme.of(context).colorScheme.onPrimary : AppColors.ink,
              ),
            ),
          const SizedBox(height: 2),
          Text(
            formatClock(message.createdAt),
            style: text.labelSmall?.copyWith(
              color: mine ? Theme.of(context).colorScheme.onPrimary.withValues(alpha: 0.7) : AppColors.muted,
            ),
          ),
        ],
      ),
    );
    if (mine) return Align(alignment: Alignment.centerRight, child: bubble);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        if (sender case final member?)
          Padding(
            padding: EdgeInsets.only(right: tokens.spaceSm, bottom: tokens.spaceSm),
            child: MemberAvatar(member: member, size: 28),
          ),
        Flexible(child: bubble),
      ],
    );
  }
}
