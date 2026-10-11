import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/supabase/supabase_providers.dart';
import '../../../core/utils/resync_signal.dart';
import '../../driving/domain/driving_activity.dart' show withoutSpikes;
import '../data/location_history_repository.dart';
import '../domain/timeline.dart';
import '../domain/track_point.dart';

final locationHistoryRepositoryProvider = Provider<LocationHistoryRepository>(
  (ref) => LocationHistoryRepository(ref.watch(supabaseClientProvider)),
);

typedef HistoryQuery = ({String userId, DateTime day});

/// Het laatste maand-overzicht: één begrensde bereikquery i.p.v. 30 losse.
/// Opgeruimd zodra niemand meer kijkt: een maand ruwe punten is groot.
final recentTimelineProvider = FutureProvider.autoDispose.family<List<TimelineEntry>, String>((
  ref,
  userId,
) async {
  final now = DateTime.now();
  final end = DateTime(now.year, now.month, now.day + 1);
  final points = await ref
      .watch(locationHistoryRepositoryProvider)
      .fetchRange(userId, DateTime(now.year, now.month, now.day - 29), end);
  return buildTimeline(withoutSpikes(points));
});

/// De tijdlijn én het ruwe routespoor van één dag, in één keer opgehaald.
/// Verblijven volgen uit de plek, dus een meetgat op dezelfde plek blijft één
/// verblijf. Ritten (buildTripTracks) en de routekaart splitsen gaten zelf, dus
/// een gat wordt nooit een rechte lijn dwars door de stad.
typedef DayHistory = ({List<TimelineEntry> entries, List<TrackPoint> points});

/// Vandaag loopt nog: zo vaak halen we de dag opnieuw op (het scherm houdt de
/// vorige gegevens zichtbaar tijdens het herladen).
const _todayRefresh = Duration(minutes: 1);

/// Een afgelopen dag verandert niet meer: zo lang blijft hij na het sluiten
/// van het scherm bewaard, zodat heen en weer wisselen niet opnieuw laadt.
const _pastDayCache = Duration(minutes: 5);

/// autoDispose: zonder kijkers stopt het verversen van vandaag. Anders bleef
/// elk ooit geopend gezinslid elke minuut zijn hele dag downloaden.
final dayHistoryProvider = FutureProvider.autoDispose.family<DayHistory, HistoryQuery>((ref, query) async {
  final repository = ref.watch(locationHistoryRepositoryProvider);
  // Vandaag is nooit af: periodiek en bij terugkeer naar de app/Verversen
  // opnieuw ophalen, anders blijft de tijdlijn hangen op het eerste laden.
  final now = DateTime.now();
  if (!isSameDay(query.day, now)) {
    final link = ref.keepAlive();
    Timer? release;
    ref.onCancel(() => release = Timer(_pastDayCache, link.close));
    ref.onResume(() => release?.cancel());
    ref.onDispose(() => release?.cancel());
  } else {
    final timer = Timer(_todayRefresh, ref.invalidateSelf);
    final resync = ref.read(resyncSignalProvider).stream.listen((_) => ref.invalidateSelf());
    ref.onDispose(() {
      timer.cancel();
      unawaited(resync.cancel());
    });
  }
  try {
    final points = withoutSpikes(sortedByTime(await repository.fetchDay(query.userId, query.day)));
    // Verblijven volgen uit de plek (clustering is tijd-onafhankelijk), zodat
    // op het werk blijven één verblijf blijft, ook al vallen er binnenshuis
    // metingen weg. Ritten komen los hiervan uit buildTripTracks (dat zelf
    // gaten opsplitst) en de routekaart splitst het spoor bij het tekenen.
    final entries = buildTimeline(points);
    return (entries: entries, points: points);
  } on Object catch (error, stackTrace) {
    debugPrint('Routespoor laden mislukt voor ${query.userId} op ${query.day}: $error');
    debugPrintStack(stackTrace: stackTrace);
    rethrow;
  }
});

bool isSameDay(DateTime a, DateTime b) => a.year == b.year && a.month == b.month && a.day == b.day;

/// Oudste eerst, ongeacht hoe de server ze teruggaf.
List<TrackPoint> sortedByTime(List<TrackPoint> points) =>
    [...points]..sort((a, b) => a.recordedAt.compareTo(b.recordedAt));
