import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_tokens.dart';
import '../../../core/utils/clock.dart';
import '../../../shared/widgets/branded_app_bar.dart';
import '../../../shared/widgets/error_view.dart';
import '../../family/domain/family_member.dart';
import '../../location/application/location_history_providers.dart';
import '../../location/domain/travel_mode.dart';
import '../../places/application/places_providers.dart';
import '../../places/domain/place.dart';
import '../application/driving_providers.dart';
import '../domain/driving_activity.dart';
import 'driving_activity_card.dart';
import 'driving_summary.dart';
import '../../../l10n/l10n.dart';
import '../../location/presentation/trip_text.dart';

/// Dagoverzicht van één gezinslid: per dag de activiteiten (verplaatsingen
/// met hun route en verblijven), nieuwste eerst.
class DrivingMemberScreen extends ConsumerWidget {
  const DrivingMemberScreen({
    super.key,
    required this.member,
    required this.familyId,
    required this.week,
    this.mode,
  });

  final FamilyMember member;
  final String familyId;

  /// Maandag van de getoonde week.
  final DateTime week;

  /// Enkel verplaatsingen met dit vervoermiddel (zonder verblijven); null
  /// toont alles.
  final TravelMode? mode;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tokens = context.tokens;
    final places = ref.watch(familyPlacesProvider(familyId)).value ?? const <Place>[];
    final now = ref.watch(clockProvider).value ?? DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    // Dagen in de toekomst hebben nog geen geschiedenis: niet ophalen.
    final days = [
      for (var i = 0; i < 7; i++)
        if (!DateTime(week.year, week.month, week.day + i).isAfter(today))
          DateTime(week.year, week.month, week.day + i),
    ];

    // Platte lijst: de ListView bouwt zo enkel de zichtbare ritkaarten op,
    // niet alle kaarten van een hele week tegelijk.
    final items = <Widget>[];
    var loading = false;
    var failed = false;
    for (final day in days.reversed) {
      final async = ref.watch(dayDrivingProvider((familyId: familyId, userId: member.userId, day: day)));
      loading = loading || async.isLoading;
      failed = failed || async.hasError;
      final driving = async.value;
      if (driving == null) continue;
      final shown = [
        for (var index = driving.activities.length - 1; index >= 0; index--)
          if (_shows(driving.activities[index])) index,
      ];
      if (shown.isEmpty) continue;
      items.add(
        Padding(
          padding: EdgeInsets.only(top: items.isEmpty ? 0 : tokens.spaceMd, bottom: tokens.spaceSm),
          child: Text(drivingDayLabel(day, now: now), style: Theme.of(context).textTheme.titleLarge),
        ),
      );
      for (final index in shown) {
        items.add(
          Padding(
            padding: EdgeInsets.only(bottom: tokens.spaceSm),
            child: DrivingActivityCard(
              activity: driving.activities[index],
              places: places,
              route: driving.trackAt(index),
            ),
          ),
        );
      }
    }

    final Widget body;
    if (items.isNotEmpty) {
      final header = Padding(
        padding: EdgeInsets.only(bottom: tokens.spaceMd),
        child: Text(
          '${drivingDate(week)} – ${drivingDate(DateTime(week.year, week.month, week.day + 6))}',
          style: Theme.of(context).textTheme.titleMedium,
        ),
      );
      body = ListView.builder(
        padding: EdgeInsets.all(tokens.spaceMd),
        itemCount: items.length + 1,
        itemBuilder: (context, index) => index == 0 ? header : items[index - 1],
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
      body = Center(
        child: Text(
          mode == null
              ? context.l10n.drivingNoHistoryWeek
              : context.l10n.drivingNoneThisWeek(mode!.noun(context.l10n, 2)),
        ),
      );
    }

    return Scaffold(
      appBar: BrandedAppBar(title: member.displayName),
      body: body,
    );
  }

  bool _shows(DrivingActivity activity) =>
      mode == null || (activity.kind == DrivingActivityKind.trip && activity.mode == mode);
}
