import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:thuisradar/core/theme/app_theme.dart';
import 'package:thuisradar/features/family/domain/family.dart';
import 'package:thuisradar/features/family/domain/family_member.dart';
import 'package:thuisradar/features/location/application/address_providers.dart';
import 'package:thuisradar/features/location/data/geocoding_source.dart';
import 'package:thuisradar/features/location/domain/place_address.dart';
import 'package:thuisradar/features/location/domain/member_location.dart';
import 'package:thuisradar/features/map/domain/member_on_map.dart';
import 'package:thuisradar/features/map/presentation/widgets/member_list_sheet.dart';
import 'package:thuisradar/features/notifications/application/events_providers.dart';
import 'package:thuisradar/features/notifications/domain/family_event.dart';
import 'package:thuisradar/features/places/application/places_providers.dart';
import 'package:thuisradar/features/places/domain/place.dart';
import 'package:thuisradar/features/places/domain/place_presence.dart';

const _family = Family(id: 'fam', name: 'Creve Family', inviteCode: 'ABC12345');

/// Geen echte geocoder in tests: adres is een verrijking.
class _NoGeocoding extends GeocodingSource {
  @override
  Future<PlaceAddress?> addressFor(double latitude, double longitude) async =>
      null;
}

MemberOnMap _member({
  required String id,
  required String name,
  int colorIndex = 0,
  MemberLocation? location,
}) => MemberOnMap(
  member: FamilyMember(
    userId: id,
    displayName: name,
    isOwner: false,
    colorIndex: colorIndex,
  ),
  location: location,
);

void main() {
  final now = DateTime(2026, 1, 2, 10, 0, 20);

  Future<void> pumpSheet(
    WidgetTester tester,
    List<MemberOnMap> members, {
    DraggableScrollableController? controller,
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
          familyPresenceProvider.overrideWith(
            (ref, id) => Stream.value([
              PlacePresence(
                userId: 'u2',
                placeId: 'home',
                isInside: true,
                since: DateTime(2026, 1, 2, 8, 3),
              ),
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
              onSelect: (_) {},
              onInvite: () {},
              onPlaces: () {},
              onAddPlace: () {},
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('toont uitnodigingskaart, familienaam en de leden', (
    tester,
  ) async {
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

    expect(
      find.text('Nodig anderen uit, blijf samen veiliger'),
      findsOneWidget,
    );
    expect(find.text('Dierbaren toevoegen'), findsOneWidget);
    expect(find.text('Creve Family'), findsOneWidget);
    expect(find.bySemanticsLabel('Personen'), findsOneWidget);
    expect(find.text('Liam (jij)'), findsOneWidget);
    expect(find.text('Sinds 10:00'), findsOneWidget);
    expect(find.text('85%'), findsOneWidget);
  });

  testWidgets('de blokken staan in de volgorde van het voorbeeld', (
    tester,
  ) async {
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

    expect(
      top('Nodig anderen uit, blijf samen veiliger'),
      lessThan(top('Creve Family')),
    );
    expect(top('Creve Family'), lessThan(chips));
    expect(chips, lessThan(top('Liam (jij)')));
  });

  testWidgets('lid zonder signaal krijgt de rode offline-staat', (
    tester,
  ) async {
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

  testWidgets(
    'korte sleepbeweging klapt het halfopen paneel niet helemaal dicht',
    (tester) async {
      final controller = DraggableScrollableController();
      addTearDown(controller.dispose);
      await pumpSheet(tester, [
        _member(id: 'u1', name: 'Liam'),
      ], controller: controller);
      final list = find
          .descendant(
            of: find.byType(MemberListSheet),
            matching: find.byType(ListView),
          )
          .first;
      final start = tester.getTopLeft(list) + const Offset(180, 12);
      final gesture = await tester.startGesture(start);
      await gesture.moveBy(const Offset(0, 40));
      await tester.pump(const Duration(milliseconds: 300));
      await gesture.up();
      await tester.pumpAndSettle();
      expect(controller.size, closeTo(0.48, 0.01));
    },
  );

  testWidgets(
    'omhoog vegen opent het paneel en daarna scrolt alleen de inhoud',
    (tester) async {
      final controller = DraggableScrollableController();
      addTearDown(controller.dispose);
      await pumpSheet(tester, [
        for (var i = 0; i < 8; i++) _member(id: 'u$i', name: 'Gezinslid $i'),
      ], controller: controller);
      final list = find
          .descendant(
            of: find.byType(MemberListSheet),
            matching: find.byType(ListView),
          )
          .first;
      await tester.dragFrom(
        tester.getTopLeft(list) + const Offset(180, 80),
        const Offset(0, -220),
      );
      await tester.pumpAndSettle();
      expect(controller.size, closeTo(0.8, 0.01));
      final scroll = tester.state<ScrollableState>(
        find.descendant(of: list, matching: find.byType(Scrollable)).first,
      );
      final before = scroll.position.pixels;
      await tester.dragFrom(
        tester.getTopLeft(list) + const Offset(180, 300),
        const Offset(0, -160),
      );
      await tester.pumpAndSettle();
      expect(controller.size, closeTo(0.8, 0.01));
      expect(scroll.position.pixels, greaterThan(before));
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('de chip Plaatsen toont het plaatsenblok', (tester) async {
    await pumpSheet(tester, [_member(id: 'u1', name: 'Liam')]);

    await tester.tap(find.bySemanticsLabel('Plaatsen'));
    await tester.pumpAndSettle();

    expect(find.text('Thuis'), findsOneWidget);
    expect(find.text('Beheer'), findsOneWidget);
    expect(find.text('Nieuwe cirkel plaatsen'), findsOneWidget);
    expect(find.textContaining('1 gezinslid hier'), findsOneWidget);
  });
}
