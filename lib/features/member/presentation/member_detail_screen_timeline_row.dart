part of 'member_detail_screen.dart';

class _TimelineRow extends StatelessWidget {
  const _TimelineRow({required this.entry});

  final TimelineEntry entry;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final tokens = context.tokens;
    final isStop = entry.kind == TimelineKind.stop;

    final title = isStop
        ? (entry.placeName == null
              ? 'Stilgestaan'
              : 'Aangekomen op ${entry.placeName}')
        : 'Onderweg · ${formatDistance(entry.distanceMeters ?? 0)}';
    final subtitle = isStop
        ? '${formatClock(entry.start)}–${formatClock(entry.end)} · ${formatDuration(entry.duration)}'
        : '${formatClock(entry.start)}–${formatClock(entry.end)} · ${formatDuration(entry.duration)}';

    return Padding(
      padding: EdgeInsets.symmetric(vertical: tokens.spaceMd),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: const BoxDecoration(
              color: AppColors.primarySoft,
              shape: BoxShape.circle,
            ),
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
                Text(
                  subtitle,
                  style: text.bodySmall?.copyWith(color: AppColors.muted),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
