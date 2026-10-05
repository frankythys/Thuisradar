import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_tokens.dart';
import '../../../core/utils/clock.dart';
import '../../../shared/widgets/branded_app_bar.dart';
import '../../../shared/widgets/error_view.dart';
import '../../family/domain/family_member.dart';
import '../../location/application/location_history_providers.dart';
import '../../location/domain/track_point.dart';
import '../../places/application/places_providers.dart';
import '../../places/domain/place.dart';
import '../../places/domain/place_timeline.dart';
import '../domain/driving_activity.dart';
import 'driving_activity_card.dart';
import 'driving_summary.dart';

/// Dagoverzicht van één gezinslid: per dag één kaart met de ritten van die dag
/// erin getekend, gevolgd door de activiteiten (ritten en verblijven).
class DrivingMemberScreen extends ConsumerWidget {
  const DrivingMemberScreen({super.key, required this.member, required this.familyId, required this.week});

  final FamilyMember member;
  final String familyId;

  /// Maandag van de getoonde week.
  final DateTime week;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tokens = context.tokens;
    final places = ref.watch(familyPlacesProvider(familyId)).value ?? const <Place>[];
    final now = ref.watch(clockProvider).value ?? DateTime.now();
    final days = [for (var i = 0; i < 7; i++) DateTime(week.year, week.month, week.day + i)];

    final sections = <Widget>[];
    var loading = false;
    var failed = false;
    for (final day in days.reversed) {
      final async = ref.watch(dayHistoryProvider((userId: member.userId, day: day)));
      loading = loading || async.isLoading;
      failed = failed || async.hasError;
      final history = async.value;
      if (history == null) continue;
      final activities = buildDayActivities(
        attachPlaceNames(history.entries, places),
        history.points,
      );
      if (activities.isEmpty) continue;
      sections.add(
        _DaySection(
          day: day,
          activities: activities,
          points: history.points,
          places: places,
          now: now,
        ),
      );
    }

    final Widget body;
    if (sections.isNotEmpty) {
      body = ListView(
        padding: EdgeInsets.all(tokens.spaceMd),
        children: [
          Text(
            '${drivingDate(days.first)} – ${drivingDate(days.last)}',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          SizedBox(height: tokens.spaceMd),
          ...sections,
        ],
      );
    } else if (loading) {
      body = const Center(child: CircularProgressIndicator());
    } else if (failed) {
      body = ErrorView(
        message: 'Dagtijdlijn laden mislukt.',
        onRetry: () {
          for (final day in days) {
            ref.invalidate(dayHistoryProvider((userId: member.userId, day: day)));
          }
        },
      );
    } else {
      body = const Center(child: Text('Geen locatiegeschiedenis deze week.'));
    }

    return Scaffold(appBar: BrandedAppBar(title: member.displayName), body: body);
  }
}

/// Eén dag: de dagtitel en de activiteiten (nieuwste eerst, zoals in het
/// voorbeeld). Elke rit krijgt zijn eigen kaart, ingezoomd op die rit.
class _DaySection extends StatelessWidget {
  const _DaySection({
    required this.day,
    required this.activities,
    required this.points,
    required this.places,
    required this.now,
  });

  final DateTime day;
  final List<DrivingActivity> activities;

  /// Alle ruwe GPS-punten van de dag: elke rit neemt er zijn eigen stuk uit.
  final List<TrackPoint> points;
  final List<Place> places;
  final DateTime now;

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    final text = Theme.of(context).textTheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(drivingDayLabel(day, now: now), style: text.titleLarge),
        SizedBox(height: tokens.spaceSm),
        for (final activity in activities.reversed) ...[
          DrivingActivityCard(
            activity: activity,
            places: places,
            route: activityTrack(activity, points),
          ),
          SizedBox(height: tokens.spaceSm),
        ],
        SizedBox(height: tokens.spaceMd),
      ],
    );
  }
}
