import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../family/application/family_providers.dart';
import '../../family/domain/family_member.dart';
import '../../location/application/location_history_providers.dart';
import '../../places/application/places_providers.dart';
import '../../places/domain/place.dart';
import '../../places/domain/place_timeline.dart';
import '../domain/day_driving.dart';
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
  final history = ref.watch(dayHistoryProvider((userId: query.userId, day: query.day)));
  final places = ref.watch(familyPlacesProvider(query.familyId)).value ?? const <Place>[];
  return history.whenData((day) => DayDriving.build(attachPlaceNames(day.entries, places), day.points));
});
