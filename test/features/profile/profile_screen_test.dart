import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:thuisradar/core/theme/app_theme.dart';
import 'package:thuisradar/features/auth/application/auth_providers.dart';
import 'package:thuisradar/features/family/application/family_providers.dart';
import 'package:thuisradar/features/family/domain/family.dart';
import 'package:thuisradar/features/family/domain/family_member.dart';
import 'package:thuisradar/features/profile/application/profile_providers.dart';
import 'package:thuisradar/features/profile/presentation/profile_screen.dart';

const _family = Family(id: 'fam', name: 'Familie Thys', inviteCode: 'K7Q2M9XA');

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  testWidgets('kop met Bewerken, locatie delen en een korte instellingenlijst', (tester) async {
    tester.view.physicalSize = const Size(1080, 2240);
    tester.view.devicePixelRatio = 2.625;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          currentUserIdProvider.overrideWithValue('papa'),
          myFamilyProvider.overrideWith((ref) async => _family),
          familyMembersProvider.overrideWith(
            (ref, id) => Stream.value(const [
              FamilyMember(
                userId: 'papa',
                displayName: 'Papa',
                isOwner: true,
                colorIndex: 0,
                phone: '+32 470 12',
              ),
              FamilyMember(userId: 'liam', displayName: 'Liam', isOwner: false, colorIndex: 3),
            ]),
          ),
          notificationPreferencesProvider.overrideWith((ref) async => <String, dynamic>{}),
        ],
        child: MaterialApp(
          theme: AppTheme.light(),
          home: const ProfileScreen(family: _family),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Papa'), findsOneWidget);
    expect(find.text('Beheerder · +32 470 12'), findsOneWidget);
    expect(find.text('Locatie delen'), findsOneWidget);
    expect(find.text('Familie Thys'), findsOneWidget);
    expect(find.text('2 leden · code K7Q2M9XA'), findsOneWidget);
    expect(find.text('Introductie opnieuw bekijken'), findsOneWidget);
    expect(find.text('Familie verlaten'), findsOneWidget);
    // Geen lang formulier meer op het scherm zelf.
    expect(find.byType(TextField), findsNothing);

    await tester.tap(find.text('Bewerken'));
    await tester.pumpAndSettle();
    expect(find.text('Profiel bewerken'), findsOneWidget);
    expect(find.widgetWithText(TextField, 'Papa'), findsOneWidget);
    expect(find.text('Kaartkleur'), findsOneWidget);
  });
}
