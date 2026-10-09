import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:thuisradar/core/theme/app_theme.dart';
import 'package:thuisradar/core/utils/clock.dart';
import 'package:thuisradar/features/family/domain/family.dart';
import 'package:thuisradar/features/family/domain/family_member.dart';
import 'package:thuisradar/features/location/application/address_providers.dart';
import 'package:thuisradar/features/location/application/location_history_providers.dart';
import 'package:thuisradar/features/location/application/location_providers.dart';
import 'package:thuisradar/features/location/data/geocoding_source.dart';
import 'package:thuisradar/features/location/domain/place_address.dart';
import 'package:thuisradar/features/location/domain/member_location.dart';
import 'package:thuisradar/features/location/domain/timeline.dart';
import 'package:thuisradar/features/location/domain/track_point.dart';
import 'package:thuisradar/features/map/domain/member_on_map.dart';
import 'package:thuisradar/features/map/presentation/widgets/member_list_sheet.dart';
import 'package:thuisradar/features/notifications/application/events_providers.dart';
import 'package:thuisradar/features/notifications/domain/family_event.dart';
import 'package:thuisradar/features/places/application/places_providers.dart';
import 'package:thuisradar/features/places/domain/place.dart';
import 'package:thuisradar/features/places/domain/place_presence.dart';
import 'package:thuisradar/features/places/presentation/place_row.dart';

const _family = Family(id: 'fam', name: 'Creve Family', inviteCode: 'ABC12345');

/// Geen echte geocoder in tests: adres is een verrijking.
class _NoGeocoding extends GeocodingSource {
  @override
  Future<PlaceAddress?> addressFor(double latitude, double longitude) async => null;
}

MemberOnMap _member({
  required String id,
  required String name,
  int colorIndex = 0,
  MemberLocation? location,
}) => MemberOnMap(
  member: FamilyMember(userId: id, displayName: name, isOwner: false, colorIndex: colorIndex),
  location: location,
);

void main() {
  final now = DateTime(2026, 1, 2, 10, 0, 20);

  Future<void> pumpSheet(
    WidgetTester tester,
    List<MemberOnMap> members, {
    DraggableScrollableController? controller,
    bool open = true,
    String? selectedUserId,
    VoidCallback? onDeselect,
  }) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          geocodingSourceProvider.overrideWithValue(_NoGeocoding()),
          familyPlacesProvider.overrideWith(
            (ref, id) => Stream.value(const [
              Place(
                id: 'home',
                familyId: 'fam',
                name: 'Thuis',
                latitude: 51,
                longitude: 3.7,
                radiusMeters: 150,
                icon: 'home',
              ),
            ]),
          ),
          clockProvider.overrideWith((ref) => Stream.value(now)),
          familyLocationsProvider.overrideWith((ref, id) => Stream.value(const <MemberLocation>[])),
          dayHistoryProvider.overrideWith(
            (ref, arg) async => (entries: const <TimelineEntry>[], points: const <TrackPoint>[]),
          ),
          recentTimelineProvider.overrideWith((ref, arg) async => const []),
          familyPresenceProvider.overrideWith(
            (ref, id) => Stream.value([
              PlacePresence(userId: 'u2', placeId: 'home', isInside: true, since: DateTime(2026, 1, 2, 8, 3)),
            ]),
          ),
          familyEventsProvider.overrideWith(
            (ref, id) => Stream.value([
              FamilyEvent(
                id: 1,
                familyId: 'fam',
                actorUserId: 'u2',
                type: FamilyEventType.arrival,
                placeId: 'home',
                createdAt: DateTime(2026, 1, 2, 8, 3),
              ),
            ]),
          ),
        ],
        child: MaterialApp(
          theme: AppTheme.light(),
          home: Scaffold(
            body: MemberListSheet(
              family: _family,
              controller: controller,
              members: members,
              currentUserId: 'u1',
              now: now,
              selectedUserId: selectedUserId,
              onSelect: (_) {},
              onDeselect: onDeselect,
              onInvite: () {},
              onPlaces: () {},
              onAddPlace: () {},
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    if (open) {
      if (controller != null) {
        controller.jumpTo(0.48);
      } else {
        await tester.dragFrom(
          tester.getTopLeft(find.byType(ClipRRect).first) + const Offset(180, 16),
          const Offset(0, -260),
        );
      }
      await tester.pumpAndSettle();
    }
  }

  testWidgets('start laag en laat geen lege ruimte onder de gezinsnaam', (tester) async {
    final controller = DraggableScrollableController();
    addTearDown(controller.dispose);
    await pumpSheet(
      tester,
      [_member(id: 'u1', name: 'Liam')],
      controller: controller,
      open: false,
    );
    final minimum = tester
        .widget<DraggableScrollableSheet>(find.byType(DraggableScrollableSheet))
        .minChildSize;
    expect(controller.size, minimum);
    final invite = find.ancestor(of: find.text('Dierbaren toevoegen'), matching: find.byType(InkWell)).first;
    final sheetBottom = tester.getBottomLeft(find.byType(DraggableScrollableSheet)).dy;
    expect(tester.getBottomLeft(invite).dy, lessThan(sheetBottom));
    expect(find.text('Dierbaren toevoegen').hitTestable(), findsOneWidget);
    await tester.drag(find.text('Nodig anderen uit, blijf samen veiliger'), const Offset(0, 400));
    await tester.pumpAndSettle();
    expect(controller.size, minimum);
    expect(find.text('Dierbaren toevoegen').hitTestable(), findsOneWidget);
    controller.jumpTo(0.94);
    await tester.pumpAndSettle();
    final gap =
        tester.getTopLeft(find.bySemanticsLabel('Personen')).dy -
        tester.getBottomLeft(find.text('Creve Family')).dy;
    expect(gap, inInclusiveRange(0, 36));
    expect(tester.takeException(), isNull);
  });

  testWidgets('bij een actief gezin geen uitnodigingskaart, wel familienaam en leden', (tester) async {
    await pumpSheet(tester, [
      _member(
        id: 'u1',
        name: 'Liam',
        location: MemberLocation(
          userId: 'u1',
          familyId: 'fam',
          latitude: 51,
          longitude: 3.7,
          battery: 85,
          updatedAt: DateTime(2026, 1, 2, 10),
        ),
      ),
      _member(id: 'u2', name: 'Frankie', colorIndex: 1),
    ]);

    expect(find.text('Nodig anderen uit, blijf samen veiliger'), findsNothing);
    expect(find.text('Dierbaren toevoegen'), findsNothing);
    expect(find.text('Voeg een persoon toe'), findsOneWidget);
    expect(find.text('Creve Family'), findsOneWidget);
    expect(find.bySemanticsLabel('Personen'), findsOneWidget);
    expect(find.text('Liam (jij)'), findsOneWidget);
    expect(find.text('Sinds 10:00'), findsOneWidget);
    expect(find.text('85%'), findsOneWidget);
  });

  testWidgets('de blokken staan in de volgorde van het voorbeeld', (tester) async {
    await pumpSheet(tester, [
      _member(
        id: 'u1',
        name: 'Liam',
        location: MemberLocation(
          userId: 'u1',
          familyId: 'fam',
          latitude: 51,
          longitude: 3.7,
          updatedAt: DateTime(2026, 1, 2, 10),
        ),
      ),
    ]);

    double top(String text) => tester.getTopLeft(find.text(text)).dy;
    final chips = tester.getTopLeft(find.bySemanticsLabel('Personen')).dy;

    expect(top('Nodig anderen uit, blijf samen veiliger'), lessThan(top('Creve Family')));
    expect(top('Creve Family'), lessThan(chips));
    expect(chips, lessThan(top('Liam (jij)')));
  });

  testWidgets('ingeklapt bij een actief gezin: familienaam en knoppen in beeld', (tester) async {
    final controller = DraggableScrollableController();
    addTearDown(controller.dispose);
    await pumpSheet(
      tester,
      [_member(id: 'u1', name: 'Liam'), _member(id: 'u2', name: 'Frankie', colorIndex: 1)],
      controller: controller,
      open: false,
    );
    final minimum = tester
        .widget<DraggableScrollableSheet>(find.byType(DraggableScrollableSheet))
        .minChildSize;
    expect(controller.size, minimum);
    expect(find.text('Nodig anderen uit, blijf samen veiliger'), findsNothing);
    expect(find.text('Creve Family').hitTestable(), findsOneWidget);
    expect(find.bySemanticsLabel('Personen').hitTestable(), findsOneWidget);
    expect(find.bySemanticsLabel('Plaatsen').hitTestable(), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('lid zonder signaal krijgt de rode offline-staat', (tester) async {
    await pumpSheet(tester, [
      _member(
        id: 'u3',
        name: 'Frankie',
        colorIndex: 3,
        location: MemberLocation(
          userId: 'u3',
          familyId: 'fam',
          latitude: 51,
          longitude: 3.7,
          battery: 65,
          updatedAt: now.subtract(const Duration(minutes: 10)),
        ),
      ),
    ]);

    expect(find.text('Geen netwerk of telefoon uit'), findsOneWidget);
    expect(find.byIcon(Icons.phonelink_off), findsOneWidget);
    expect(find.text('65%'), findsOneWidget);
  });

  testWidgets('korte sleepbeweging klapt het halfopen paneel niet helemaal dicht', (tester) async {
    final controller = DraggableScrollableController();
    addTearDown(controller.dispose);
    await pumpSheet(tester, [_member(id: 'u1', name: 'Liam')], controller: controller);
    final list = find.descendant(of: find.byType(MemberListSheet), matching: find.byType(ListView)).first;
    final start = tester.getTopLeft(list) + const Offset(180, 12);
    final gesture = await tester.startGesture(start);
    await gesture.moveBy(const Offset(0, 40));
    await tester.pump(const Duration(milliseconds: 300));
    await gesture.up();
    await tester.pumpAndSettle();
    // Het paneel volgt de vinger (geen snap) en blijft ruim open.
    expect(controller.size, greaterThan(0.3));
  });

  testWidgets('omhoog vegen opent het paneel en daarna scrolt alleen de inhoud', (tester) async {
    final controller = DraggableScrollableController();
    addTearDown(controller.dispose);
    await pumpSheet(tester, [
      for (var i = 0; i < 8; i++) _member(id: 'u$i', name: 'Gezinslid $i'),
    ], controller: controller);
    final list = find.descendant(of: find.byType(MemberListSheet), matching: find.byType(ListView)).first;
    // Groot genoeg slepen opent het paneel volledig (geen snap-punten meer).
    await tester.dragFrom(tester.getTopLeft(list) + const Offset(180, 80), const Offset(0, -500));
    await tester.pumpAndSettle();
    expect(controller.size, closeTo(0.94, 0.01));
    final scroll = tester.state<ScrollableState>(
      find.descendant(of: list, matching: find.byType(Scrollable)).first,
    );
    final before = scroll.position.pixels;
    final familyTop = tester.getTopLeft(find.text('Creve Family'));
    final chips = find.bySemanticsLabel('Personen');
    final chipsTop = tester.getTopLeft(chips);
    await tester.dragFrom(tester.getTopLeft(list) + const Offset(180, 300), const Offset(0, -160));
    await tester.pumpAndSettle();
    expect(controller.size, closeTo(0.94, 0.01));
    expect(scroll.position.pixels, greaterThan(before));
    expect(tester.getTopLeft(find.text('Creve Family')), familyTop);
    // De keuzeknoppen blijven onder de familienaam staan tijdens het scrollen.
    expect(tester.getTopLeft(chips), chipsTop);
    // Zelfde volgorde als bij het kiezen van een persoon op de kaart.
    scroll.position.jumpTo(0);
    final minimum = tester
        .widget<DraggableScrollableSheet>(find.byType(DraggableScrollableSheet))
        .minChildSize;
    controller.animateTo(minimum, duration: const Duration(milliseconds: 250), curve: Curves.easeOut);
    await tester.pumpAndSettle();
    expect(controller.size, closeTo(minimum, 0.01));
    expect(scroll.position.pixels, 0);
    expect(find.text('Creve Family').hitTestable(), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('de knoppen blijven staan als de ledenlijst scrolt', (tester) async {
    final controller = DraggableScrollableController();
    addTearDown(controller.dispose);
    await pumpSheet(tester, [
      for (var i = 0; i < 8; i++) _member(id: 'u$i', name: 'Gezinslid $i'),
    ], controller: controller);
    controller.jumpTo(0.94);
    await tester.pumpAndSettle();

    final chips = find.bySemanticsLabel('Personen');
    final placesChip = find.bySemanticsLabel('Plaatsen');
    final startTop = tester.getTopLeft(chips).dy;
    final nameBottom = tester.getBottomLeft(find.text('Creve Family')).dy;

    await tester.drag(find.byType(ListView).first, const Offset(0, -260));
    await tester.pumpAndSettle();

    expect(tester.getTopLeft(chips).dy, startTop);
    expect(tester.getTopLeft(placesChip).dy, startTop);
    // Onder de familienaam, dus niet losgekomen van de kop.
    expect(tester.getTopLeft(chips).dy, greaterThan(nameBottom));
    // De lijst is wel echt opgeschoven.
    expect(tester.getTopLeft(find.text('Gezinslid 0')).dy, lessThan(nameBottom));
    expect(controller.size, closeTo(0.94, 0.01));
    expect(tester.takeException(), isNull);
  });

  testWidgets('bij een gekozen persoon verdwijnen familienaam en knoppen', (tester) async {
    final controller = DraggableScrollableController();
    addTearDown(controller.dispose);
    await pumpSheet(
      tester,
      [
        _member(
          id: 'u2',
          name: 'Franky',
          location: MemberLocation(
            userId: 'u2',
            familyId: 'fam',
            latitude: 51,
            longitude: 3.7,
            updatedAt: DateTime(2026, 1, 2, 10),
          ),
        ),
      ],
      controller: controller,
      selectedUserId: 'u2',
      onDeselect: () {},
    );
    controller.jumpTo(0.94);
    await tester.pumpAndSettle();

    // Het infoscherm over de persoon staat er wel.
    expect(find.text('Franky'), findsOneWidget);
    expect(find.text('Terug naar personen'), findsOneWidget);
    // De familienaam en de 2 keuzeknoppen mogen er niet staan.
    expect(find.text('Creve Family'), findsNothing);
    expect(find.bySemanticsLabel('Personen'), findsNothing);
    expect(find.bySemanticsLabel('Plaatsen'), findsNothing);
    expect(find.text('Nodig anderen uit, blijf samen veiliger'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('de chip Plaatsen toont dezelfde rijen als het Plaatsen-scherm', (tester) async {
    await pumpSheet(tester, [_member(id: 'u1', name: 'Liam'), _member(id: 'u2', name: 'Franky')]);

    await tester.tap(find.bySemanticsLabel('Plaatsen'));
    await tester.pumpAndSettle();

    expect(find.text('Thuis'), findsOneWidget);
    expect(find.text('Beheer'), findsOneWidget);
    expect(find.text('Plaats toevoegen'), findsOneWidget);
    expect(find.byType(PlaceRow), findsOneWidget);
    expect(find.text('150 m · Aankomst & vertrek'), findsOneWidget);
    expect(find.byTooltip('Franky is hier'), findsOneWidget);
    // Verwijderen gebeurt via Beheer, niet vanuit het kaartpaneel.
    expect(find.byTooltip('Opties'), findsNothing);
  });
}
