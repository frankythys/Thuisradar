import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:thuisradar/core/theme/app_theme.dart';
import 'package:thuisradar/core/utils/clock.dart';
import 'package:thuisradar/features/family/domain/family_member.dart';
import 'package:thuisradar/features/location/application/location_history_providers.dart';
import 'package:thuisradar/features/location/domain/timeline.dart';
import 'package:thuisradar/features/member/presentation/member_detail_screen.dart';
import 'package:thuisradar/features/places/application/places_providers.dart';
import 'package:thuisradar/features/places/domain/place.dart';

const _member = FamilyMember(userId: 'u1', displayName: 'Papa', isOwner: true, colorIndex: 0);

Future<void> _pump(WidgetTester tester, Future<List<TimelineEntry>> Function() result) {
  return tester.pumpWidget(
    ProviderScope(
      overrides: [
        // Vaste klok: geen periodieke timer die pumpAndSettle laat hangen.
        clockProvider.overrideWith((ref) => Stream.value(DateTime(2026, 1, 2, 10))),
        timelineProvider.overrideWith((ref, arg) => result()),
        familyPlacesProvider.overrideWith((ref, arg) => Stream.value(const <Place>[])),
      ],
      child: MaterialApp(
        theme: AppTheme.light(),
        home: const MemberDetailScreen(member: _member, familyId: 'fam'),
      ),
    ),
  );
}

void main() {
  testWidgets('lege geschiedenis toont de lege staat, geen oneindig laden', (tester) async {
    await _pump(tester, () async => <TimelineEntry>[]);
    await tester.pumpAndSettle();

    expect(find.byType(CircularProgressIndicator), findsNothing);
    expect(find.text('Geen geschiedenis'), findsOneWidget);
  });

  testWidgets('een fout toont een melding met "Opnieuw proberen"', (tester) async {
    await _pump(tester, () async => throw Exception('kapot'));
    await tester.pumpAndSettle();

    expect(find.byType(CircularProgressIndicator), findsNothing);
    expect(find.textContaining('Geschiedenis laden mislukt'), findsOneWidget);
    expect(find.text('Opnieuw proberen'), findsOneWidget);
  });
}
