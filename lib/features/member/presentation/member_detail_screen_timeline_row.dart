part of 'member_detail_screen.dart';

class _TimelineRow extends StatelessWidget {
  const _TimelineRow({required this.entry, this.onSaveAsPlace});

  final TimelineEntry entry;
  final VoidCallback? onSaveAsPlace;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final tokens = context.tokens;
    final isStop = entry.kind == TimelineKind.stop;

    final l10n = context.l10n;
    final title = isStop
        ? (entry.placeName == null ? l10n.memberStopped : l10n.memberArrivedAt(entry.placeName!))
        : '${l10n.tripMoving} · ${formatDistance(l10n, entry.distanceMeters ?? 0)}';
    final subtitle = isStop
        ? '${formatClock(entry.start)}–${formatClock(entry.end)} · ${formatDuration(l10n, entry.duration)}'
        : '${formatClock(entry.start)}–${formatClock(entry.end)} · ${formatDuration(l10n, entry.duration)}';

    return Padding(
      padding: EdgeInsets.symmetric(vertical: tokens.spaceMd),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: const BoxDecoration(color: AppColors.primarySoft, shape: BoxShape.circle),
            child: Icon(
              isStop ? Icons.place : Icons.directions_car_filled_outlined,
              size: 20,
              color: AppColors.primary,
            ),
          ),
          SizedBox(width: tokens.spaceMd),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: text.titleMedium),
                SizedBox(height: tokens.spaceXs),
                Text(subtitle, style: text.bodySmall?.copyWith(color: AppColors.muted)),
              ],
            ),
          ),
          if (isStop && entry.placeName == null && onSaveAsPlace != null)
            IconButton(
              tooltip: l10n.memberSaveAsPlace,
              onPressed: onSaveAsPlace,
              icon: const Icon(Icons.add_location_alt_outlined, color: AppColors.primary),
            ),
        ],
      ),
    );
  }
}
