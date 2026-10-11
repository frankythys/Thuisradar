import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../family/application/family_providers.dart';
import '../../family/domain/family_member.dart';
import '../../location/application/location_history_providers.dart';
import '../../location/data/location_history_repository.dart' show dayBounds;
import '../../location/domain/timeline.dart';
import '../../places/application/places_providers.dart';
import '../../places/domain/place.dart';
import '../../places/domain/place_timeline.dart';
import '../domain/day_driving.dart';
import '../domain/driving_activity.dart' show withoutSpikes;
import '../domain/driving_report.dart';

typedef DrivingQuery = ({String familyId, DateTime week});
typedef MemberDrivingReport = ({FamilyMember member, DrivingReport report});

final drivingReportsProvider = FutureProvider.autoDispose.family<List<MemberDrivingReport>, DrivingQuery>((
  ref,
  query,
) async {
  final members = await ref.watch(familyMembersProvider(query.familyId).future);
  final repository = ref.watch(locationHistoryRepositoryProvider);
  final start = drivingWeekStart(query.week);
  return Future.wait(
    members.map((member) async {
      final points = await repository.fetchRange(member.userId, start, drivingWeekEnd(start));
      return (member: member, report: buildDrivingReport(points, start));
    }),
  );
});

typedef DayDrivingQuery = ({String familyId, String userId, DateTime day});

/// Ritten en verblijven van één dag met het spoor van elke rit, berekend
/// wanneer de geschiedenis of de plaatsen veranderen — niet bij elke
/// klok-tik van het scherm.
final dayDrivingProvider = Provider.autoDispose.family<AsyncValue<DayDriving>, DayDrivingQuery>((ref, query) {
  final historyQuery = (userId: query.userId, day: query.day);
  final history = ref.watch(dayHistoryProvider(historyQuery));
  final places = ref.watch(familyPlacesProvider(query.familyId)).value ?? const <Place>[];
  // Zolang de marge laadt of faalt: enkel de dag zelf, zoals vroeger.
  final margins = ref.watch(dayMarginsProvider(historyQuery)).value;
  return history.whenData((day) {
    if (margins == null || (margins.before.isEmpty && margins.after.isEmpty)) {
      return DayDriving.build(attachPlaceNames(day.entries, places), day.points);
    }
    final points = sortedByTime([...margins.before, ...day.points, ...margins.after]);
    final (from, to) = dayBounds(query.day);
    return DayDriving.build(
      attachPlaceNames(buildTimeline(withoutSpikes(points)), places),
      points,
      from: from,
      to: to,
    );
  });
});
