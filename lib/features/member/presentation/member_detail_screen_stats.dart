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
    final seen = location == null
        ? '—'
        : formatRelative(location!.updatedAt, now: now);

    return Row(
      children: [
        Expanded(
          child: _StatCard(
            icon: Icons.battery_full,
            value: location?.battery == null ? '—' : '${location!.battery}%',
            label: location?.isCharging == true ? 'Opladen' : 'Batterij',
          ),
        ),
        SizedBox(width: tokens.spaceMd),
        Expanded(
          child: _StatCard(
            icon: Icons.route_outlined,
            value: formatDistance(distance),
            label: 'Afstand',
          ),
        ),
        SizedBox(width: tokens.spaceMd),
        Expanded(
          child: _StatCard(
            icon: Icons.schedule,
            value: seen,
            label: 'Laatst gezien',
          ),
        ),
      ],
    );
  }
}
