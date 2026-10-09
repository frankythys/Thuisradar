import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:thuisradar/core/theme/app_theme.dart';
import 'package:thuisradar/core/utils/clock.dart';
import 'package:thuisradar/features/family/domain/family_member.dart';
import 'package:thuisradar/features/location/application/location_history_providers.dart';
import 'package:thuisradar/features/location/application/address_providers.dart';
import 'package:thuisradar/features/location/application/location_providers.dart';
import 'package:thuisradar/features/location/data/geocoding_source.dart';
import 'package:thuisradar/features/location/domain/place_address.dart';
import 'package:thuisradar/features/location/domain/member_location.dart';
import 'package:thuisradar/features/location/domain/timeline.dart';
import 'package:thuisradar/features/location/domain/track_point.dart';
import 'package:thuisradar/features/member/presentation/member_detail_screen.dart';
import 'package:thuisradar/features/places/application/places_providers.dart';
import 'package:thuisradar/features/places/domain/place.dart';

class _NoGeocoding extends GeocodingSource {
  @override
  Future<PlaceAddress?> addressFor(double latitude, double longitude) async => null;
}

const _member = FamilyMember(userId: 'u1', displayName: 'Papa', isOwner: true, colorIndex: 0);

Future<void> _pump(WidgetTester tester, Future<List<TimelineEntry>> Function() result, {Widget? home}) {
  return tester.pumpWidget(
    ProviderScope(
      overrides: [
        // Vaste klok: geen periodieke timer die pumpAndSettle laat hangen.
        clockProvider.overrideWith((ref) => Stream.value(DateTime(2026, 1, 2, 10))),
        dayHistoryProvider.overrideWith(
          (ref, arg) async => (entries: await result(), points: const <TrackPoint>[]),
        ),
        familyPlacesProvider.overrideWith((ref, arg) => Stream.value(const <Place>[])),
        // Geen echte Supabase-stroom nodig voor deze schermtests.
        familyLocationsProvider.overrideWith((ref, arg) => Stream.value(const <MemberLocation>[])),
        geocodingSourceProvider.overrideWithValue(_NoGeocoding()),
      ],
      child: MaterialApp(
        theme: AppTheme.light(),
        home: home ?? const MemberDetailScreen(member: _member, familyId: 'fam'),
      ),
    ),
  );
}

void main() {
  testWidgets('een doorlopende veeg opent het persoonsvenster voorbij de compacte hoogte', (tester) async {
    tester.view.physicalSize = const Size(360, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final controller = DraggableScrollableController();
    addTearDown(controller.dispose);
    await _pump(
      tester,
      () async => <TimelineEntry>[],
      home: Scaffold(
        body: DraggableScrollableSheet(
          controller: controller,
          initialChildSize: 0.48,
          minChildSize: 0.14,
          maxChildSize: 0.94,
          builder: (context, scroll) => Material(
            child: MemberDetailScreen(
              member: _member,
              familyId: 'fam',
              scrollController: scroll,
              onBack: () {},
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    final gesture = await tester.startGesture(tester.getCenter(find.text('Papa')));
    for (var i = 0; i < 10; i++) {
      await gesture.moveBy(const Offset(0, -40));
      await tester.pump();
    }
    await gesture.up();
    await tester.pumpAndSettle();
    expect(controller.size, closeTo(0.94, 0.01));
    // Ook de vaste kop moet dezelfde lijst bedienen, zonder eigen scrollgebied.
    expect(find.byType(Scrollable), findsOneWidget);
    final collapse = await tester.startGesture(tester.getCenter(find.text('Terug naar personen')));
    for (var i = 0; i < 20; i++) {
      await collapse.moveBy(const Offset(0, 40));
      await tester.pump();
    }
    await collapse.up();
    await tester.pumpAndSettle();
    expect(controller.size, closeTo(0.14, 0.01));
    final reopen = await tester.startGesture(tester.getCenter(find.byType(Divider).first));
    for (var i = 0; i < 20; i++) {
      await reopen.moveBy(const Offset(0, -40));
      await tester.pump();
    }
    await reopen.up();
    await tester.pumpAndSettle();
    expect(controller.size, closeTo(0.94, 0.01));
    expect(tester.takeException(), isNull);
  });

  testWidgets('persoonskop past ook tijdens inklappen op een klein scherm', (tester) async {
    tester.view.physicalSize = const Size(360, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final controller = DraggableScrollableController();
    addTearDown(controller.dispose);
    await _pump(
      tester,
      () async => <TimelineEntry>[],
      home: Scaffold(
        body: DraggableScrollableSheet(
          controller: controller,
          initialChildSize: 0.14,
          minChildSize: 0.14,
          maxChildSize: 0.94,
          builder: (context, scroll) => Material(
            child: MemberDetailScreen(
              member: _member,
              familyId: 'fam',
              scrollController: scroll,
              onBack: () {},
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    for (final size in [0.3, 0.6, 0.94, 0.14]) {
      controller.jumpTo(size);
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull, reason: 'Paneelhoogte $size');
    }
    controller.jumpTo(0.94);
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(find.text('Bellen'), 200, scrollable: find.byType(Scrollable).last);
    // Met de lagere kop kan de knop net op de rand staan: helemaal in beeld brengen.
    await tester.ensureVisible(find.text('Bellen'));
    await tester.pumpAndSettle();
    expect(find.text('Bellen').hitTestable(), findsOneWidget);
  });

  testWidgets('details blijven sleepbaar in onderpaneel en bieden terugknop', (tester) async {
    final controller = DraggableScrollableController();
    addTearDown(controller.dispose);
    var returned = false;
    await _pump(
      tester,
      () async => <TimelineEntry>[],
      home: Scaffold(
        body: DraggableScrollableSheet(
          controller: controller,
          initialChildSize: 0.48,
          minChildSize: 0.14,
          maxChildSize: 0.94,
          builder: (context, scrollController) => Material(
            child: MemberDetailScreen(
              member: _member,
              familyId: 'fam',
              scrollController: scrollController,
              onBack: () => returned = true,
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Papa'), findsOneWidget);
    expect(find.byType(Scaffold), findsOneWidget);
    await tester.drag(find.text('Papa'), const Offset(0, -180));
    await tester.pumpAndSettle();
    expect(controller.size, greaterThan(0.48));
    await tester.tap(find.text('Terug naar personen'));
    expect(returned, isTrue);
    expect(tester.takeException(), isNull);
  });

  testWidgets('terugknop en identiteit blijven staan, de rest scrolt', (tester) async {
    final controller = DraggableScrollableController();
    addTearDown(controller.dispose);
    await _pump(
      tester,
      () async => <TimelineEntry>[],
      home: DraggableScrollableSheet(
        controller: controller,
        initialChildSize: 0.94,
        minChildSize: 0.14,
        maxChildSize: 0.94,
        builder: (context, scrollController) => Material(
          child: MemberDetailScreen(
            member: _member,
            familyId: 'fam',
            scrollController: scrollController,
            onBack: () {},
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final back = find.text('Terug naar personen');
    final name = find.text('Papa');
    final backTop = tester.getTopLeft(back).dy;
    final nameTop = tester.getTopLeft(name).dy;
    final statsTop = tester.getTopLeft(find.text('Batterij', skipOffstage: false)).dy;

    await tester.drag(find.byType(ListView), const Offset(0, -200));
    await tester.pumpAndSettle();

    // Terugknop, naam en status blijven op dezelfde plek staan.
    expect(tester.getTopLeft(back).dy, backTop);
    expect(tester.getTopLeft(name).dy, nameTop);
    expect(find.text('Terug naar personen'), findsOneWidget);
    // De stats eronder zijn wel omhoog geschoven.
    expect(tester.getTopLeft(find.text('Batterij', skipOffstage: false)).dy, lessThan(statsTop));
    expect(tester.takeException(), isNull);
  });

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

  testWidgets('stilstaan op een onbekende plek biedt "Deze plek opslaan als plaats"', (tester) async {
    await _pump(
      tester,
      () async => <TimelineEntry>[],
      home: MemberDetailScreen(
        member: _member,
        familyId: 'fam',
        location: MemberLocation(
          userId: 'u1',
          familyId: 'fam',
          latitude: 51.2,
          longitude: 4.4,
          speedMps: 0,
          updatedAt: DateTime(2026, 1, 2, 9, 59, 40),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Deze plek opslaan als plaats'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('zonder locatie geen opslaanknop', (tester) async {
    await _pump(tester, () async => <TimelineEntry>[]);
    await tester.pumpAndSettle();
    expect(find.text('Deze plek opslaan als plaats'), findsNothing);
  });
}
