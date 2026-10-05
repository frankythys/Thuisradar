import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

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
    final query = (familyId: widget.family.id, week: _week);
    final reports = ref.watch(drivingReportsProvider(query));
    final current = drivingWeekStart(DateTime.now());
    return Scaffold(
      appBar: BrandedAppBar(title: widget.family.name),
      body: Column(
        children: [
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: EdgeInsets.all(tokens.spaceMd),
            child: Row(
              children: [
                for (var index = 0; index < 12; index++) ...[
                  Builder(
                    builder: (context) {
                      final start = DateTime(current.year, current.month, current.day - index * 7);
                      final end = DateTime(start.year, start.month, start.day + 6);
                      return ChoiceChip(
                        label: Text(
                          index == 0
                              ? 'Deze week'
                              : index == 1
                              ? 'Vorige week'
                              : '${drivingDate(start)} – ${drivingDate(end)}',
                        ),
                        selected: _week == start,
                        onSelected: (_) => setState(() => _week = start),
                      );
                    },
                  ),
                  SizedBox(width: tokens.spaceSm),
                ],
              ],
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
                    if (data.isEmpty) const Text('Er zijn nog geen gezinsleden.'),
                    for (final item in data) ...[
                      AppCard(
                        onTap: () => Navigator.of(context).push(
                          MaterialPageRoute<void>(
                            builder: (_) => DrivingMemberScreen(data: item, week: _week),
                          ),
                        ),
                        child: Row(
                          children: [
                            MemberAvatar(member: item.member),
                            SizedBox(width: tokens.spaceMd),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    item.member.displayName,
                                    style: Theme.of(context).textTheme.titleLarge,
                                  ),
                                  SizedBox(height: tokens.spaceXs),
                                  Text(
                                    !item.report.hasHistory
                                        ? 'Geen locatiegeschiedenis'
                                        : item.report.trips.isEmpty
                                        ? 'Nog geen ritten'
                                        : '${item.report.trips.length} ${item.report.trips.length == 1 ? 'rit' : 'ritten'} · ${drivingNumber(item.report.kilometers)} kilometer',
                                  ),
                                  SizedBox(height: tokens.spaceSm),
                                  Text(
                                    'Rijincidenten: niet gemeten',
                                    style: Theme.of(context).textTheme.bodySmall,
                                  ),
                                ],
                              ),
                            ),
                            const Icon(Icons.chevron_right),
                          ],
                        ),
                      ),
                      SizedBox(height: tokens.spaceMd),
                    ],
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
