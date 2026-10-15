part of 'member_detail_screen.dart';

class _Stats extends StatelessWidget {
  const _Stats({required this.location, required this.timeline, required this.now});

  final MemberLocation? location;
  final List<TimelineEntry> timeline;
  final DateTime now;

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    final distance = timeline
        .where((e) => e.kind == TimelineKind.move)
        .fold<double>(0, (sum, e) => sum + (e.distanceMeters ?? 0));
    final seen = location == null ? '—' : formatRelative(context.l10n, location!.updatedAt, now: now);

    return Row(
      children: [
        Expanded(
          child: _StatCard(
            icon: Icons.battery_full,
            value: location?.battery == null ? '—' : '${location!.battery}%',
            label: location?.isCharging == true ? context.l10n.memberCharging : context.l10n.memberBattery,
          ),
        ),
        SizedBox(width: tokens.spaceMd),
        Expanded(
          child: _StatCard(
            icon: Icons.route_outlined,
            value: formatDistance(context.l10n, distance),
            label: context.l10n.memberDistance,
          ),
        ),
        SizedBox(width: tokens.spaceMd),
        Expanded(
          child: _StatCard(icon: Icons.schedule, value: seen, label: context.l10n.memberLastSeen),
        ),
      ],
    );
  }
}
