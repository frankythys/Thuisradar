import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_tokens.dart';
import '../../../core/utils/clock.dart';
import '../../../core/utils/time_format.dart';
import '../../../shared/widgets/app_card.dart';
import '../../../shared/widgets/branded_app_bar.dart';
import '../../../shared/widgets/empty_state.dart';
import '../../../shared/widgets/error_view.dart';
import '../../../shared/widgets/member_avatar.dart';
import '../../family/domain/family_member.dart';
import '../../location/application/location_history_providers.dart';
import '../../location/domain/member_location.dart';
import '../../location/domain/timeline.dart';

/// Scherm 12: detail van één gezinslid met stats en de dagtijdlijn.
class MemberDetailScreen extends ConsumerStatefulWidget {
  const MemberDetailScreen({super.key, required this.member, this.location});

  final FamilyMember member;
  final MemberLocation? location;

  @override
  ConsumerState<MemberDetailScreen> createState() => _MemberDetailScreenState();
}

class _MemberDetailScreenState extends ConsumerState<MemberDetailScreen> {
  int _dayOffset = 0;

  static const _dayLabels = ['Vandaag', 'Gisteren', 'Eergisteren'];

  DateTime get _selectedDay => DateTime.now().subtract(Duration(days: _dayOffset));

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    final location = widget.location;
    final query = (userId: widget.member.userId, day: _selectedDay);
    final timeline = ref.watch(timelineProvider(query));

    return Scaffold(
      appBar: const BrandedAppBar(title: 'Gezinslid'),
      body: SafeArea(
        child: ListView(
          padding: EdgeInsets.all(tokens.spaceLg),
          children: [
            _Header(member: widget.member, location: location),
            SizedBox(height: tokens.spaceLg),
            _Stats(location: location, timeline: timeline.value ?? const []),
            SizedBox(height: tokens.spaceLg),
            _DayChips(selected: _dayOffset, onSelected: (i) => setState(() => _dayOffset = i)),
            SizedBox(height: tokens.spaceLg),
            Text('Locatiegeschiedenis', style: Theme.of(context).textTheme.titleLarge),
            SizedBox(height: tokens.spaceSm),
            timeline.when(
              data: (entries) => _Timeline(entries: entries),
              loading: () => const Padding(
                padding: EdgeInsets.all(32),
                child: Center(child: CircularProgressIndicator()),
              ),
              error: (e, _) => ErrorView(message: 'Geschiedenis laden mislukt.\n$e'),
            ),
          ],
        ),
      ),
    );
  }
}

class _Header extends ConsumerWidget {
  const _Header({required this.member, required this.location});

  final FamilyMember member;
  final MemberLocation? location;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final text = Theme.of(context).textTheme;
    final tokens = context.tokens;
    final now = ref.watch(clockProvider).value ?? DateTime.now();
    final speed = speedKmh(location?.speedMps);
    final moving = speed != null;

    return Column(
      children: [
        MemberAvatar(member: member, size: 96, statusColor: location == null ? null : AppColors.primary),
        SizedBox(height: tokens.spaceMd),
        Text(member.displayName, style: text.headlineLarge, textAlign: TextAlign.center),
        SizedBox(height: tokens.spaceSm),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
          decoration: const ShapeDecoration(color: AppColors.primarySoft, shape: StadiumBorder()),
          child: Text(
            location == null ? 'Nog geen locatie' : (moving ? 'Onderweg' : 'Stilstaand'),
            style: text.labelLarge?.copyWith(color: AppColors.primary),
          ),
        ),
        if (location != null) ...[
          SizedBox(height: tokens.spaceSm),
          Text(
            moving
                ? 'Snelheid: $speed km/u · bijgewerkt ${formatRelative(location!.updatedAt, now: now)}'
                : 'Bijgewerkt ${formatRelative(location!.updatedAt, now: now)}',
            style: text.bodyMedium?.copyWith(color: AppColors.muted),
            textAlign: TextAlign.center,
          ),
        ],
      ],
    );
  }
}

class _Stats extends StatelessWidget {
  const _Stats({required this.location, required this.timeline});

  final MemberLocation? location;
  final List<TimelineEntry> timeline;

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    final distance = timeline
        .where((e) => e.kind == TimelineKind.move)
        .fold<double>(0, (sum, e) => sum + (e.distanceMeters ?? 0));
    final stops = timeline.where((e) => e.kind == TimelineKind.stop).length;

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
          child: _StatCard(icon: Icons.route_outlined, value: formatDistance(distance), label: 'Vandaag'),
        ),
        SizedBox(width: tokens.spaceMd),
        Expanded(
          child: _StatCard(icon: Icons.place_outlined, value: '$stops', label: 'Stops'),
        ),
      ],
    );
  }
}

class _StatCard extends StatelessWidget {
  const _StatCard({required this.icon, required this.value, required this.label});

  final IconData icon;
  final String value;
  final String label;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final tokens = context.tokens;

    return AppCard(
      padding: EdgeInsets.all(tokens.spaceMd),
      child: Column(
        children: [
          Icon(icon, color: AppColors.primary),
          SizedBox(height: tokens.spaceSm),
          Text(value, style: text.titleLarge),
          Text(label, style: text.bodySmall?.copyWith(color: AppColors.muted)),
        ],
      ),
    );
  }
}

class _DayChips extends StatelessWidget {
  const _DayChips({required this.selected, required this.onSelected});

  final int selected;
  final ValueChanged<int> onSelected;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final tokens = context.tokens;

    return Row(
      children: [
        for (final (index, label) in _MemberDetailScreenState._dayLabels.indexed)
          Padding(
            padding: EdgeInsets.only(right: tokens.spaceSm),
            child: Material(
              color: index == selected ? AppColors.primary : Colors.white,
              shape: const StadiumBorder(),
              child: InkWell(
                onTap: () => onSelected(index),
                customBorder: const StadiumBorder(),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
                  child: Text(
                    label,
                    style: text.labelLarge?.copyWith(color: index == selected ? Colors.white : AppColors.ink),
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}

class _Timeline extends StatelessWidget {
  const _Timeline({required this.entries});

  final List<TimelineEntry> entries;

  @override
  Widget build(BuildContext context) {
    if (entries.isEmpty) {
      return const EmptyState(
        icon: Icons.history,
        title: 'Geen geschiedenis',
        message: 'Voor deze dag is er nog geen locatiegeschiedenis.',
      );
    }

    // Nieuwste bovenaan.
    final ordered = entries.reversed.toList();
    return AppCard(
      child: Column(
        children: [
          for (final (index, entry) in ordered.indexed) ...[
            if (index > 0) const Divider(height: 1),
            _TimelineRow(entry: entry),
          ],
        ],
      ),
    );
  }
}

class _TimelineRow extends StatelessWidget {
  const _TimelineRow({required this.entry});

  final TimelineEntry entry;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final tokens = context.tokens;
    final isStop = entry.kind == TimelineKind.stop;

    final title = isStop
        ? (entry.placeName ?? 'Stilgestaan')
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
        ],
      ),
    );
  }
}
