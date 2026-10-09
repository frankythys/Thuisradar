import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:thuisradar/core/theme/app_theme.dart';
import 'package:thuisradar/features/family/application/family_providers.dart';
import 'package:thuisradar/features/family/domain/family.dart';
import 'package:thuisradar/features/family/domain/family_member.dart';
import 'package:thuisradar/features/location/application/location_providers.dart';
import 'package:thuisradar/features/location/domain/member_location.dart';
import 'package:thuisradar/features/notifications/application/events_providers.dart';
import 'package:thuisradar/features/notifications/domain/family_event.dart';
import 'package:thuisradar/features/notifications/presentation/notifications_screen.dart';
import 'package:thuisradar/features/places/application/places_providers.dart';
import 'package:thuisradar/features/places/domain/place.dart';

const _family = Family(id: 'fam', name: 'Familie Thys', inviteCode: 'ABC12345');

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  testWidgets('één titel, filters, batterij met belknop, meldingen per dag en wissen in het menu', (
    tester,
  ) async {
    final now = DateTime.now();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          familyMembersProvider.overrideWith(
            (ref, id) => Stream.value(const [
              FamilyMember(
                userId: 'liam',
                displayName: 'Liam',
                isOwner: false,
                colorIndex: 3,
                phone: '+32470',
              ),
            ]),
          ),
          familyPlacesProvider.overrideWith(
            (ref, id) => Stream.value(const [
              Place(
                id: 'p',
                familyId: 'fam',
                name: 'School',
                latitude: 51,
                longitude: 4,
                radiusMeters: 150,
                icon: 'school',
              ),
            ]),
          ),
          familyLocationsProvider.overrideWith(
            (ref, id) => Stream.value([
              MemberLocation(
                userId: 'liam',
                familyId: 'fam',
                latitude: 51,
                longitude: 4,
                battery: 12,
                updatedAt: now,
              ),
            ]),
          ),
          familyEventsProvider.overrideWith(
            (ref, id) => Stream.value([
              FamilyEvent(
                id: 1,
                familyId: 'fam',
                actorUserId: 'liam',
                type: FamilyEventType.arrival,
                placeId: 'p',
                createdAt: now,
              ),
              FamilyEvent(
                id: 2,
                familyId: 'fam',
                actorUserId: 'liam',
                type: FamilyEventType.departure,
                placeId: 'p',
                createdAt: now.subtract(const Duration(days: 1)),
              ),
            ]),
          ),
        ],
        child: MaterialApp(
          theme: AppTheme.light(),
          home: const NotificationsScreen(family: _family),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Meldingen'), findsOneWidget);
    expect(find.text('Alles gelezen'), findsNothing);
    expect(find.text('Liam: batterij 12%'), findsOneWidget);
    expect(find.text('Bel'), findsOneWidget);
    expect(find.text('Start navigatie'), findsNothing);
    expect(find.text('VANDAAG'), findsOneWidget);
    expect(find.text('GISTEREN'), findsOneWidget);
    expect(find.text('Liam is aangekomen op School'), findsOneWidget);

    await tester.tap(find.text('Vertrek'));
    await tester.pumpAndSettle();
    expect(find.text('Liam is aangekomen op School'), findsNothing);
    expect(find.text('Liam is vertrokken van School'), findsOneWidget);
    expect(find.text('Liam: batterij 12%'), findsNothing);

    await tester.tap(find.byTooltip('Meer opties'));
    await tester.pumpAndSettle();
    expect(find.text('Meldingen wissen'), findsOneWidget);
  });
}
