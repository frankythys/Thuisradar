import 'package:thuisradar/features/auth/application/auth_providers.dart';
import 'package:thuisradar/features/family/application/family_providers.dart';
import 'package:thuisradar/features/family/domain/family_member.dart';
import 'package:thuisradar/features/family/presentation/welcome_screen.dart';
import 'package:thuisradar/features/location/application/location_providers.dart';
import 'package:thuisradar/features/location/application/location_tracker.dart';
import 'package:thuisradar/features/location/application/tracking_status.dart';
import 'package:thuisradar/features/location/application/location_history_providers.dart';
import 'package:thuisradar/features/location/data/device_location_source.dart';
import 'package:thuisradar/features/location/domain/device_reading.dart';
import 'package:thuisradar/features/location/domain/member_location.dart';
import 'package:thuisradar/features/location/domain/timeline.dart';
import 'package:thuisradar/features/location/domain/track_point.dart';
import 'package:thuisradar/features/map/presentation/map_screen.dart';
import 'package:thuisradar/features/member/presentation/member_detail_screen.dart';
import 'package:thuisradar/features/places/application/places_providers.dart';
import 'package:thuisradar/features/places/domain/place.dart';
import 'package:thuisradar/features/places/domain/place_presence.dart';
import 'package:thuisradar/features/places/presentation/places_screen.dart';
import 'package:thuisradar/features/places/presentation/add_place_screen.dart';
import 'package:thuisradar/features/notifications/application/events_providers.dart';
import 'package:thuisradar/features/notifications/domain/family_event.dart';
import 'package:thuisradar/features/notifications/presentation/notifications_screen.dart';
import 'package:thuisradar/features/chat/application/chat_providers.dart';
import 'package:thuisradar/features/chat/domain/message.dart';
import 'package:thuisradar/features/chat/presentation/chat_screen.dart';
import 'package:thuisradar/features/sos/application/sos_providers.dart';
import 'package:thuisradar/features/sos/domain/sos_alert.dart';
import 'package:thuisradar/features/sos/presentation/sos_screen.dart';
import 'package:thuisradar/features/sos/presentation/sos_received_overlay.dart';
import 'package:thuisradar/features/profile/application/profile_providers.dart';
import 'package:thuisradar/features/profile/presentation/profile_screen.dart';
import 'package:thuisradar/core/utils/clock.dart';
import 'package:thuisradar/shared/widgets/app_bottom_nav.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:thuisradar/core/theme/app_theme.dart';
import 'package:thuisradar/features/onboarding/presentation/onboarding_screen.dart';
import 'package:thuisradar/features/auth/presentation/login_screen.dart';
import 'package:thuisradar/features/family/domain/family.dart';
import 'package:thuisradar/features/family/presentation/family_setup_screen.dart';
import 'package:thuisradar/features/family/presentation/invite_screen.dart';
import 'package:thuisradar/features/permissions/presentation/permissions_screen.dart';

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  Future<void> show(WidgetTester tester, Widget screen) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          currentUserIdProvider.overrideWithValue('lucas'),
          myFamilyProvider.overrideWith((ref) async => family),
          sosReceiptsProvider.overrideWith(
            (ref, id) => Stream.value([
              {'user_id': 'papa', 'on_the_way': false},
            ]),
          ),
          recentTimelineProvider.overrideWith((ref, id) async => history),
          clockProvider.overrideWith((ref) => Stream.value(now)),
          familyMembersProvider.overrideWith((ref, id) => Stream.value(members)),
          familyLocationsProvider.overrideWith((ref, id) => Stream.value(id == 'offline' ? [] : locations)),
          familyPlacesProvider.overrideWith((ref, id) => Stream.value(places)),
          familyPresenceProvider.overrideWith(
            (ref, id) => Stream.value([
              PlacePresence(
                userId: 'papa',
                placeId: 'home',
                isInside: true,
                since: now.subtract(const Duration(hours: 2)),
              ),
            ]),
          ),
          familyMessagesProvider.overrideWith((ref, id) => Stream.value(messages)),
          familyEventsProvider.overrideWith((ref, id) => Stream.value(events)),
          timelineProvider.overrideWith((ref, query) async => history),
          dayHistoryProvider.overrideWith(
            (ref, query) async => (entries: history, points: const <TrackPoint>[]),
          ),
          activeSosProvider.overrideWith((ref, id) => Stream.value([])),
          locationTrackerProvider.overrideWith(
            () => _VisualTracker(
              offline:
                  screen is Scaffold &&
                  screen.body is MapScreen &&
                  (screen.body as MapScreen).family.id == 'offline',
            ),
          ),
          deviceLocationSourceProvider.overrideWithValue(_VisualLocation()),
          notificationPreferencesProvider.overrideWith((ref) async => {}),
        ],
        child: MaterialApp(debugShowCheckedModeBanner: false, theme: AppTheme.light(), home: screen),
      ),
    );
    await tester.pumpAndSettle(
      const Duration(milliseconds: 100),
      EnginePhase.sendSemanticsUpdate,
      const Duration(seconds: 15),
    );
  }

  Future<void> capture(WidgetTester tester, String name) async {
    await tester.runAsync(() => Future<void>.delayed(const Duration(seconds: 2)));
    await tester.pumpAndSettle();
    await binding.convertFlutterSurfaceToImage();
    await tester.pump();
    await binding.takeScreenshot(name);
    debugPrint('CAPTURED $name');
  }

  for (var i = 1; i <= 4; i++) {
    testWidgets('0${i}_onboarding', (tester) async {
      await show(tester, const OnboardingScreen());
      for (var page = 1; page < i; page++) {
        await tester.tap(find.text('Volgende'));
        await tester.pumpAndSettle();
      }
      await capture(tester, '0${i}_onboarding');
    });
  }
  for (final entry in <String, Widget>{
    '06_inloggen': const LoginScreen(),
    '07_familie_kiezen': const FamilySetupScreen(),
    '08_familie_uitnodigen': const InviteScreen(
      family: Family(id: 'visual-test', name: 'Familie Thys', inviteCode: 'A7K2M9QX'),
    ),
    '10_toestemmingen': const PermissionsScreen(),
    '09_welkom': const WelcomeScreen(family: family),
    '11_kaart': _nav(const MapScreen(family: family), AppTab.kaart),
    '12_gezinslid': MemberDetailScreen(
      member: members.first,
      familyId: 'visual-test',
      location: locations.first,
    ),
    '13_plaatsen': _nav(const PlacesScreen(family: family), AppTab.plaatsen),
    '14_plaats_toevoegen': const AddPlaceScreen(familyId: 'visual-test'),
    '15_meldingen': const NotificationsScreen(family: family),
    '16_familiechat': _nav(const ChatScreen(family: family), AppTab.chat),
    '17_sos': SosScreen(familyId: 'visual-test', onActivate: () async {}),
    '18_sos_ontvangen': SosReceivedOverlay(
      alert: SosAlert(
        id: 'sos',
        familyId: 'visual-test',
        userId: 'lucas',
        latitude: 51.05,
        longitude: 3.73,
        active: true,
        createdAt: now,
      ),
      name: 'Lucas',
      onShowOnMap: () {},
      onDismiss: () {},
    ),
    '19_profiel': const ProfileScreen(family: family),
    '20_offline': _nav(
      const MapScreen(
        family: Family(id: 'offline', name: 'Familie Thys', inviteCode: 'A7K2M9QX'),
      ),
      AppTab.kaart,
    ),
  }.entries) {
    testWidgets(entry.key, (tester) async {
      await show(tester, entry.value);
      await capture(tester, entry.key);
    });
  }
  for (final entry in <String, Widget>{
    '10_toestemmingen_onder': const PermissionsScreen(),
    '12_gezinslid_onder': MemberDetailScreen(
      member: members.first,
      familyId: 'visual-test',
      location: locations.first,
    ),
    '13_plaatsen_onder': _nav(const PlacesScreen(family: family), AppTab.plaatsen),
    '14_plaats_onder': const AddPlaceScreen(familyId: 'visual-test'),
    '17_sos_onder': SosScreen(familyId: 'visual-test', onActivate: () async {}),
    '19_profiel_onder': const ProfileScreen(family: family),
  }.entries) {
    testWidgets(entry.key, (tester) async {
      await show(tester, entry.value);
      final scroll = find.byType(Scrollable).first;
      await tester.drag(scroll, const Offset(0, -1700));
      await tester.pumpAndSettle();
      await capture(tester, entry.key);
    });
  }
  testWidgets('05_registreren', (tester) async {
    await show(tester, const LoginScreen());
    await tester.ensureVisible(find.text('Nieuw? Maak een account'));
    await tester.tap(find.text('Nieuw? Maak een account'));
    await tester.pumpAndSettle();
    await capture(tester, '05_registreren');
  });
}

const family = Family(id: 'visual-test', name: 'Familie Thys', inviteCode: 'A7K2M9QX');
final now = DateTime(2026, 10, 3, 17, 55);
const members = [
  FamilyMember(userId: 'mama', displayName: 'Mama (Sofie)', isOwner: false, colorIndex: 0),
  FamilyMember(userId: 'papa', displayName: 'Papa (Peter)', isOwner: true, colorIndex: 1),
  FamilyMember(userId: 'lucas', displayName: 'Lucas (Jij)', isOwner: false, colorIndex: 2),
];
final locations = [
  MemberLocation(
    userId: 'mama',
    familyId: 'visual-test',
    latitude: 51.054,
    longitude: 3.72,
    battery: 64,
    speedMps: 11.7,
    updatedAt: now,
  ),
  MemberLocation(
    userId: 'papa',
    familyId: 'visual-test',
    latitude: 51.048,
    longitude: 3.727,
    battery: 82,
    updatedAt: now,
  ),
  MemberLocation(
    userId: 'lucas',
    familyId: 'visual-test',
    latitude: 51.06,
    longitude: 3.74,
    battery: 15,
    updatedAt: now,
  ),
];
const places = [
  Place(
    id: 'home',
    familyId: 'visual-test',
    name: 'Thuis',
    address: 'Kerkstraat 42, 9000 Gent',
    latitude: 51.048,
    longitude: 3.727,
    radiusMeters: 150,
    icon: 'home',
  ),
  Place(
    id: 'school',
    familyId: 'visual-test',
    name: 'School (Sint-Jan)',
    address: 'Leopoldstraat 18, Gent',
    latitude: 51.058,
    longitude: 3.72,
    radiusMeters: 200,
    icon: 'school',
    watchedMembers: ['lucas'],
  ),
  Place(
    id: 'work',
    familyId: 'visual-test',
    name: 'Werk (Mama)',
    address: 'Kortrijksesteenweg, Gent',
    latitude: 51.045,
    longitude: 3.73,
    radiusMeters: 250,
    icon: 'work',
    watchedMembers: ['mama'],
  ),
  Place(
    id: 'sport',
    familyId: 'visual-test',
    name: 'Sportclub (KHC Hockey)',
    address: 'Sportlaan, Gent',
    latitude: 51.06,
    longitude: 3.74,
    radiusMeters: 300,
    icon: 'sports',
    notifyDeparture: false,
  ),
];
final messages = [
  Message(
    id: 1,
    familyId: 'visual-test',
    userId: 'papa',
    body: 'Ik ben al thuis en begin aan het eten. Hoe laat zijn jullie er?',
    createdAt: now.subtract(const Duration(minutes: 11)),
  ),
  Message(
    id: 2,
    familyId: 'visual-test',
    userId: 'lucas',
    body: 'Training is net begonnen tot 18:45. Daarna fiets ik direct naar huis!',
    createdAt: now.subtract(const Duration(minutes: 9)),
  ),
  Message(
    id: 3,
    familyId: 'visual-test',
    userId: 'mama',
    body: 'https://www.google.com/maps?q=51.054,3.72',
    createdAt: now.subtract(const Duration(minutes: 5)),
  ),
  Message(
    id: 4,
    familyId: 'visual-test',
    userId: 'lucas',
    body: 'Top, rij voorzichtig! Eten staat klaar rond kwart over zes.',
    createdAt: now.subtract(const Duration(minutes: 3)),
  ),
];
final events = [
  FamilyEvent(
    id: 1,
    familyId: 'visual-test',
    actorUserId: 'mama',
    type: FamilyEventType.departure,
    placeId: 'work',
    createdAt: now.subtract(const Duration(minutes: 7)),
  ),
  FamilyEvent(
    id: 2,
    familyId: 'visual-test',
    actorUserId: 'papa',
    type: FamilyEventType.arrival,
    placeId: 'home',
    createdAt: now.subtract(const Duration(hours: 1)),
  ),
  FamilyEvent(
    id: 3,
    familyId: 'visual-test',
    actorUserId: 'lucas',
    type: FamilyEventType.arrival,
    placeId: 'sport',
    createdAt: now.subtract(const Duration(hours: 2)),
  ),
];
final history = [
  TimelineEntry(
    kind: TimelineKind.stop,
    start: now.subtract(const Duration(hours: 10)),
    end: now.subtract(const Duration(hours: 9)),
    latitude: 51.048,
    longitude: 3.727,
    placeName: 'Thuis',
  ),
  TimelineEntry(
    kind: TimelineKind.move,
    start: now.subtract(const Duration(hours: 9)),
    end: now.subtract(const Duration(hours: 8)),
    latitude: 51.045,
    longitude: 3.73,
    distanceMeters: 3100,
  ),
  TimelineEntry(
    kind: TimelineKind.stop,
    start: now.subtract(const Duration(hours: 8)),
    end: now.subtract(const Duration(minutes: 7)),
    latitude: 51.045,
    longitude: 3.73,
    placeName: 'Werk',
  ),
];
Widget _nav(Widget child, AppTab tab) => Scaffold(
  body: child,
  bottomNavigationBar: AppBottomNav(
    offline: child is MapScreen && child.family.id == 'offline',
    current: tab,
    onSelected: (_) {},
  ),
);

class _VisualTracker extends LocationTracker {
  _VisualTracker({this.offline = false});
  final bool offline;
  @override
  TrackingStatus build() => offline ? TrackingStatus.offline : TrackingStatus.active;
  @override
  Future<void> start({required String userId, required String familyId}) async {}
  @override
  void setFastUpdates(bool fast) {}
}

class _VisualLocation extends DeviceLocationSource {
  @override
  Future<DevicePosition?> currentPosition({Duration timeout = const Duration(seconds: 8)}) async =>
      DevicePosition(latitude: 51.05, longitude: 3.73, timestamp: now);
}
