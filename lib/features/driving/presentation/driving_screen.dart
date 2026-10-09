import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_tokens.dart';
import '../../../shared/widgets/app_card.dart';
import '../../../shared/widgets/branded_app_bar.dart';
import '../../../shared/widgets/error_view.dart';
import '../../../shared/widgets/member_avatar.dart';
import '../../family/domain/family.dart';
import '../application/driving_providers.dart';
import '../domain/driving_report.dart';
import 'driving_member_screen.dart';
import 'driving_summary.dart';
import 'driving_week_picker.dart';

/// Weekoverzicht van de ritten: week kiezen, drie kerncijfers en per
/// gezinslid een rij die naar de ritten van die persoon leidt.
class DrivingScreen extends ConsumerStatefulWidget {
  const DrivingScreen({super.key, required this.family});
  final Family family;

  @override
  ConsumerState<DrivingScreen> createState() => _DrivingScreenState();
}

class _DrivingScreenState extends ConsumerState<DrivingScreen> {
  late DateTime _week = drivingWeekStart(DateTime.now());

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    final text = Theme.of(context).textTheme;
    final query = (familyId: widget.family.id, week: _week);
    final reports = ref.watch(drivingReportsProvider(query));
    return Scaffold(
      appBar: const BrandedAppBar(title: 'Rijden'),
      body: Column(
        children: [
          Padding(
            padding: EdgeInsets.fromLTRB(tokens.spaceMd, tokens.spaceSm, tokens.spaceMd, 0),
            child: DrivingWeekPicker(
              week: _week,
              currentWeek: drivingWeekStart(DateTime.now()),
              onChanged: (week) => setState(() => _week = week),
            ),
          ),
          Expanded(
            child: reports.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (error, stack) => ErrorView(
                message: 'Het rijoverzicht kon niet worden geladen.',
                onRetry: () => ref.invalidate(drivingReportsProvider(query)),
              ),
              data: (data) => RefreshIndicator(
                onRefresh: () async {
                  try {
                    await ref.refresh(drivingReportsProvider(query).future).then<void>((_) {});
                  } catch (_) {
                    // De provider toont de laadfout met een herhaalactie.
                  }
                },
                child: ListView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: EdgeInsets.all(tokens.spaceMd),
                  children: [
                    DrivingSummary(reports: data),
                    SizedBox(height: tokens.spaceLg),
                    Text('PER GEZINSLID', style: text.labelSmall?.copyWith(color: AppColors.muted)),
                    SizedBox(height: tokens.spaceSm),
                    if (data.isEmpty)
                      const Text('Er zijn nog geen gezinsleden.')
                    else
                      AppCard(
                        padding: EdgeInsets.zero,
                        child: Column(
                          children: [
                            for (final (index, item) in data.indexed) ...[
                              if (index > 0) const Divider(height: 1),
                              _MemberRow(
                                item: item,
                                onTap: () => Navigator.of(context).push(
                                  MaterialPageRoute<void>(
                                    builder: (_) => DrivingMemberScreen(
                                      member: item.member,
                                      familyId: widget.family.id,
                                      week: _week,
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    SizedBox(height: tokens.spaceMd),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Icon(Icons.info_outline, size: 18, color: AppColors.muted),
                        SizedBox(width: tokens.spaceSm),
                        Expanded(
                          child: Text(
                            'Schatting op basis van GPS. Fietsen, openbaar vervoer of meerijden kan ook als '
                            'rit tellen. Rijgedrag (remmen, gsm) wordt nog niet gemeten.',
                            style: text.bodySmall?.copyWith(color: AppColors.muted),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _MemberRow extends StatelessWidget {
  const _MemberRow({required this.item, required this.onTap});

  final MemberDrivingReport item;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final tokens = context.tokens;
    final report = item.report;
    final count = report.trips.length;
    final subtitle = !report.hasHistory
        ? 'Geen locatiegeschiedenis'
        : count == 0
        ? 'Geen ritten'
        : '$count ${count == 1 ? 'rit' : 'ritten'} · ${drivingNumber(report.kilometers)} km';
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: tokens.spaceMd, vertical: tokens.spaceSm + tokens.spaceXs),
        child: Row(
          children: [
            MemberAvatar(member: item.member, size: 40),
            SizedBox(width: tokens.spaceMd),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(item.member.displayName, style: text.titleMedium),
                  Text(subtitle, style: text.bodySmall?.copyWith(color: AppColors.muted)),
                ],
              ),
            ),
            const Icon(Icons.chevron_right, color: AppColors.muted),
          ],
        ),
      ),
    );
  }
}
