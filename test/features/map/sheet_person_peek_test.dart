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
import 'package:thuisradar/features/location/domain/member_location.dart';
import 'package:thuisradar/features/location/domain/place_address.dart';
import 'package:thuisradar/features/location/domain/timeline.dart';
import 'package:thuisradar/features/location/domain/track_point.dart';
import 'package:thuisradar/features/map/domain/member_on_map.dart';
import 'package:thuisradar/features/map/presentation/widgets/member_list_sheet.dart';
import 'package:thuisradar/features/map/presentation/widgets/member_sheet_dimensions.dart';
import 'package:thuisradar/features/notifications/application/events_providers.dart';
import 'package:thuisradar/features/places/application/places_providers.dart';

class _NoGeocoding extends GeocodingSource {
  @override
  Future<PlaceAddress?> addressFor(double latitude, double longitude) async => null;
}

void main() {
  testWidgets('persoonsscherm in het paneel: zelfde standen en greep als de ledenlijst', (tester) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    final now = DateTime(2026, 10, 9, 12);
    final controller = DraggableScrollableController();
    addTearDown(controller.dispose);
    late double peekHeight;
    final location = MemberLocation(
      userId: 'u2',
      familyId: 'fam',
      latitude: 51.1,
      longitude: 4,
      updatedAt: now,
    );
    final members = [
      MemberOnMap(
        member: const FamilyMember(userId: 'u1', displayName: 'Franky', isOwner: true, colorIndex: 0),
        location: MemberLocation(userId: 'u1', familyId: 'fam', latitude: 51, longitude: 4, updatedAt: now),
      ),
      MemberOnMap(
        member: const FamilyMember(userId: 'u2', displayName: 'Liam', isOwner: false, colorIndex: 1),
        location: location,
      ),
    ];

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          geocodingSourceProvider.overrideWithValue(_NoGeocoding()),
          familyPlacesProvider.overrideWith((ref, id) => Stream.value(const [])),
          clockProvider.overrideWith((ref) => Stream.value(now)),
          familyLocationsProvider.overrideWith((ref, id) => Stream.value([location])),
          dayHistoryProvider.overrideWith(
            (ref, arg) async => (entries: const <TimelineEntry>[], points: const <TrackPoint>[]),
          ),
          recentTimelineProvider.overrideWith((ref, arg) async => const []),
          familyPresenceProvider.overrideWith((ref, id) => Stream.value(const [])),
          familyEventsProvider.overrideWith((ref, id) => Stream.value(const [])),
        ],
        child: MaterialApp(
          theme: AppTheme.light(),
          home: Scaffold(
            body: Builder(
              builder: (context) {
                peekHeight = MemberSheetDimensions.peekHeight(context);
                return MemberListSheet(
                  family: const Family(id: 'fam', name: 'Gezin', inviteCode: 'ABC12345'),
                  controller: controller,
                  members: members,
                  now: now,
                  selectedUserId: 'u2',
                  onDeselect: () {},
                  onSelect: (_) {},
                  onInvite: () {},
                  onPlaces: () {},
                  onAddPlace: () {},
                );
              },
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    final rest = controller.pixels;
    const screen = 800.0;

    Future<void> dragHandle(double dy) async {
      final top = screen - controller.pixels;
      await tester.timedDragFrom(Offset(180, top + 8), Offset(0, dy), const Duration(milliseconds: 600));
      await tester.pumpAndSettle();
    }

    // Gewone stand: de knop terug en de naam staan volledig in beeld.
    final sheetTop = screen - rest;
    expect(tester.getTopLeft(find.text('Terug naar personen')).dy, greaterThan(sheetTop));
    expect(tester.getBottomLeft(find.text('Liam').first).dy, lessThan(screen));

    // Ver naar beneden: enkel de greep, net als bij de ledenlijst.
    await dragHandle(rest);
    expect(controller.pixels, moreOrLessEquals(peekHeight, epsilon: 1));
    expect(
      tester.getTopLeft(find.text('Terug naar personen')).dy,
      greaterThanOrEqualTo(screen),
      reason: 'laagste stand: enkel de greep, geen halve knop',
    );

    // Van onder in één keer ver omhoog: eerst stoppen op de gewone stand.
    await dragHandle(-600);
    expect(controller.pixels, moreOrLessEquals(rest, epsilon: 1));

    // Van hoog in één keer ver naar beneden: stopt eerst op de gewone stand.
    controller.jumpTo(0.94);
    await tester.pumpAndSettle();
    await dragHandle(700);
    expect(controller.pixels, moreOrLessEquals(rest, epsilon: 1));
  });
}
