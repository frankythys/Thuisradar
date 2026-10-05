import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../family/application/family_providers.dart';
import '../../family/domain/family_member.dart';
import '../../location/application/location_history_providers.dart';
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
      final points = await repository
          .fetchRange(member.userId, start, drivingWeekEnd(start))
          .timeout(const Duration(seconds: 20));
      return (member: member, report: buildDrivingReport(points, start));
    }),
  );
});
