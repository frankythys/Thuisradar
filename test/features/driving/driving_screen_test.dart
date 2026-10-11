import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:thuisradar/core/theme/app_theme.dart';
import 'package:thuisradar/features/driving/application/driving_providers.dart';
import 'package:thuisradar/features/driving/domain/driving_report.dart';
import 'package:thuisradar/features/driving/presentation/driving_screen.dart';
import 'package:thuisradar/features/family/domain/family.dart';
import 'package:thuisradar/features/family/domain/family_member.dart';
import 'package:thuisradar/features/location/application/location_history_providers.dart';
import 'package:thuisradar/features/location/domain/timeline.dart';
import 'package:thuisradar/features/location/domain/track_point.dart';
import 'package:thuisradar/features/location/domain/travel_mode.dart';
import 'package:thuisradar/features/places/application/places_providers.dart';
import 'package:thuisradar/features/places/domain/place.dart';

void main() {
  testWidgets('weken wisselen, details openen en geen betaalmuur op smal scherm', (tester) async {
    tester.view.physicalSize = const Size(360, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final queries = <DrivingQuery>[];
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          drivingReportsProvider.overrideWith((ref, query) async {
            queries.add(query);
            return [
              (
                member: const FamilyMember(userId: '1', displayName: 'Liam', isOwner: false, colorIndex: 0),
                report: DrivingReport(const [], hasHistory: true),
              ),
            ];
          }),
          // Geen daggeschiedenis in deze test: het detail toont de lege staat.
          dayHistoryProvider.overrideWith(
            (ref, query) async => (entries: const <TimelineEntry>[], points: const <TrackPoint>[]),
          ),
          familyPlacesProvider.overrideWith((ref, id) => Stream.value(const <Place>[])),
        ],
        child: MaterialApp(
          theme: AppTheme.light(),
          home: const DrivingScreen(
            family: Family(id: 'family', name: 'Ons gezin', inviteCode: 'abc'),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Onderweg'), findsOneWidget);
    expect(find.text('Deze week'), findsOneWidget);
    expect(find.text('PER GEZINSLID'), findsOneWidget);
    expect(find.byIcon(Icons.lock), findsNothing);
    expect(find.textContaining('abonnement'), findsNothing);
    await tester.tap(find.byTooltip('Week ervoor'));
    await tester.pumpAndSettle();
    expect(
      queries.last.week,
      drivingWeekStart(DateTime(DateTime.now().year, DateTime.now().month, DateTime.now().day - 7)),
    );
    await tester.scrollUntilVisible(find.text('Liam'), 150, scrollable: find.byType(Scrollable).last);
    await tester.tap(find.text('Liam'));
    await tester.pumpAndSettle();
    expect(find.text('Geen locatiegeschiedenis deze week.'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
  testWidgets('laadfout heeft een werkende herhaalactie', (tester) async {
    var attempts = 0;
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          drivingReportsProvider.overrideWith((ref, query) async {
            if (++attempts == 1) throw StateError('offline');
            return [];
          }),
        ],
        child: MaterialApp(
          theme: AppTheme.light(),
          home: const DrivingScreen(
            family: Family(id: 'family', name: 'Ons gezin', inviteCode: 'abc'),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Opnieuw proberen'));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.text('Er zijn nog geen gezinsleden.'),
      150,
      scrollable: find.byType(Scrollable).last,
    );
    expect(find.text('Er zijn nog geen gezinsleden.'), findsOneWidget);
  });

  testWidgets('de filter toont enkel de wandelingen met hun cijfers', (tester) async {
    tester.view.physicalSize = const Size(360, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final walk = DrivingTrip(
      start: DateTime(2026, 10, 6, 14),
      end: DateTime(2026, 10, 6, 14, 45),
      kilometers: 3.6,
      topSpeed: 5,
      mode: TravelMode.walk,
    );
    final drive = DrivingTrip(
      start: DateTime(2026, 10, 6, 17),
      end: DateTime(2026, 10, 6, 17, 20),
      kilometers: 18,
      topSpeed: 90,
    );
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          drivingReportsProvider.overrideWith(
            (ref, query) async => [
              (
                member: const FamilyMember(userId: '1', displayName: 'Liam', isOwner: false, colorIndex: 0),
                report: DrivingReport([walk, drive], hasHistory: true),
              ),
            ],
          ),
        ],
        child: MaterialApp(
          theme: AppTheme.light(),
          home: const DrivingScreen(
            family: Family(id: 'family', name: 'Ons gezin', inviteCode: 'abc'),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    // Standaard alles samen.
    expect(find.text('verplaatsingen'), findsOneWidget);
    expect(find.text('2 verplaatsingen · 21,6 km'), findsOneWidget);

    await tester.tap(find.byTooltip('Wandelen'));
    await tester.pumpAndSettle();
    expect(find.text('wandeling'), findsOneWidget);
    expect(find.text('3,6'), findsOneWidget);
    expect(find.text('0u45'), findsOneWidget);
    expect(find.text('1 wandeling · 3,6 km'), findsOneWidget);

    await tester.tap(find.byTooltip('Rijden'));
    await tester.pumpAndSettle();
    expect(find.text('1 rit · 18,0 km'), findsOneWidget);
    expect(find.text('90'), findsOneWidget);

    await tester.tap(find.byTooltip('Fietsen'));
    await tester.pumpAndSettle();
    expect(find.text('Geen fietstochten'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
