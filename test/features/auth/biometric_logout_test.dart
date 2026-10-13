import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:local_auth/local_auth.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:thuisradar/core/push/push_providers.dart';
import 'package:thuisradar/core/push/push_service.dart';
import 'package:thuisradar/core/theme/app_theme.dart';
import 'package:thuisradar/features/auth/application/auth_providers.dart';
import 'package:thuisradar/features/auth/data/auth_repository.dart';
import 'package:thuisradar/features/auth/data/biometric_login.dart';
import 'package:thuisradar/features/auth/presentation/login_screen.dart';
import 'package:thuisradar/features/family/application/family_providers.dart';
import 'package:thuisradar/features/family/domain/family.dart';
import 'package:thuisradar/features/family/domain/family_member.dart';
import 'package:thuisradar/features/geofencing/application/geofence_status.dart';
import 'package:thuisradar/features/geofencing/application/geofence_sync.dart';
import 'package:thuisradar/features/geofencing/application/geofencing_providers.dart';
import 'package:thuisradar/features/location/application/location_providers.dart';
import 'package:thuisradar/features/location/application/location_tracker.dart';
import 'package:thuisradar/features/location/application/tracking_status.dart';
import 'package:thuisradar/features/profile/application/profile_providers.dart';
import 'package:thuisradar/features/profile/presentation/profile_screen.dart';

class _Auth extends Mock implements AuthRepository {}

class _Local extends Mock implements LocalAuthentication {}

class _Push extends Mock implements PushService {}

class _Tracker extends LocationTracker {
  @override
  TrackingStatus build() => TrackingStatus.idle;

  @override
  void stop({String? reason}) {}
}

class _Zones extends GeofenceSync {
  @override
  GeofenceStatus build() => GeofenceStatus.idle;

  @override
  Future<void> stop() async {}
}

void main() {
  testWidgets('eenmalig instellen op het inlogscherm blijft werken na herhaald uitloggen', (tester) async {
    FlutterSecureStorage.setMockInitialValues({});
    SharedPreferences.setMockInitialValues({});
    const family = Family(id: 'fam', name: 'Familie Thys', inviteCode: 'K7Q2M9XA');
    final signedIn = ValueNotifier(false);
    addTearDown(signedIn.dispose);
    final auth = _Auth();
    final local = _Local();
    final push = _Push();
    final biometric = BiometricLogin(local: local);
    when(() => local.getAvailableBiometrics()).thenAnswer((_) async => [BiometricType.fingerprint]);
    when(() => local.authenticate(localizedReason: any(named: 'localizedReason'), biometricOnly: true))
        .thenAnswer((_) async => true);
    when(() => auth.signIn(email: 'test@example.com', password: 'test-password')).thenAnswer((_) async {
      signedIn.value = true;
    });
    when(() => auth.signOut()).thenAnswer((_) async {
      signedIn.value = false;
    });
    when(() => push.forgetServerToken()).thenAnswer((_) async {});
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          authRepositoryProvider.overrideWithValue(auth),
          biometricLoginProvider.overrideWithValue(biometric),
          currentUserIdProvider.overrideWithValue('papa'),
          familyMembersProvider.overrideWith(
            (ref, id) => Stream.value(const [
              FamilyMember(userId: 'papa', displayName: 'Papa', isOwner: true, colorIndex: 0),
            ]),
          ),
          familyInviteProvider.overrideWith((ref, id) async => family),
          notificationPreferencesProvider.overrideWith((ref) async => <String, dynamic>{}),
          locationTrackerProvider.overrideWith(_Tracker.new),
          geofenceSyncProvider.overrideWith(_Zones.new),
          pushServiceProvider.overrideWithValue(push),
        ],
        child: MaterialApp(
          theme: AppTheme.light(),
          home: ValueListenableBuilder<bool>(
            valueListenable: signedIn,
            builder: (context, value, child) =>
                value ? const ProfileScreen(family: family) : const LoginScreen(),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextFormField).at(0), 'test@example.com');
    await tester.enterText(find.byType(TextFormField).at(1), 'test-password');
    await tester.ensureVisible(find.byTooltip('Inloggen met biometrie'));
    await tester.tap(find.byTooltip('Inloggen met biometrie'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 350));
    await tester.tap(find.text('Inschakelen'));
    await tester.pumpAndSettle();
    expect(find.byType(ProfileScreen), findsOneWidget);

    for (var i = 0; i < 2; i++) {
      await tester.scrollUntilVisible(find.text('Uitloggen'), 300);
      await tester.tap(find.text('Uitloggen'));
      await tester.pumpAndSettle();
      expect(find.byType(LoginScreen), findsOneWidget);
      expect(await biometric.enabled, isTrue, reason: 'Uitloggen mag de vingerscanlogin niet wissen.');
      final fields = tester.widgetList<TextFormField>(find.byType(TextFormField)).toList();
      expect(fields[1].controller!.text, isEmpty);
      await tester.ensureVisible(find.byTooltip('Inloggen met biometrie'));
      await tester.tap(find.byTooltip('Inloggen met biometrie'));
      await tester.pumpAndSettle();
      expect(find.text('Biometrie inschakelen'), findsNothing);
      expect(find.byType(ProfileScreen), findsOneWidget);
    }
    verify(() => auth.signOut()).called(2);
    verify(() => auth.signIn(email: 'test@example.com', password: 'test-password')).called(3);
    verify(() => local.authenticate(localizedReason: any(named: 'localizedReason'), biometricOnly: true))
        .called(3);
    expect(tester.takeException(), isNull);
  });
}
