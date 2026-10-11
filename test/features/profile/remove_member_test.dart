import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:thuisradar/core/theme/app_theme.dart';
import 'package:thuisradar/features/auth/application/auth_providers.dart';
import 'package:thuisradar/features/family/application/family_providers.dart';
import 'package:thuisradar/features/family/data/family_repository.dart';
import 'package:thuisradar/features/family/domain/family.dart';
import 'package:thuisradar/features/family/domain/family_member.dart';
import 'package:thuisradar/features/profile/application/profile_providers.dart';
import 'package:thuisradar/features/profile/presentation/profile_screen.dart';

class _Repo extends Mock implements FamilyRepository {}

const _family = Family(id: 'fam', name: 'Familie Thys', inviteCode: 'K7Q2M9XA');

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  Future<_Repo> pump(WidgetTester tester, {required String me}) async {
    final repo = _Repo();
    when(() => repo.fetchInvite('fam')).thenAnswer((_) async => _family);
    when(() => repo.removeMember('fam', 'liam')).thenAnswer((_) async {});
    tester.view.physicalSize = const Size(1080, 2240);
    tester.view.devicePixelRatio = 2.625;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          familyRepositoryProvider.overrideWithValue(repo),
          currentUserIdProvider.overrideWithValue(me),
          myFamilyProvider.overrideWith((ref) async => _family),
          familyMembersProvider.overrideWith(
            (ref, id) => Stream.value(const [
              FamilyMember(userId: 'papa', displayName: 'Papa', isOwner: true, colorIndex: 0),
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
    await tester.tap(find.text('Familie Thys'));
    await tester.pumpAndSettle();
    return repo;
  }

  testWidgets('de beheerder verwijdert een lid na bevestiging', (tester) async {
    final repo = await pump(tester, me: 'papa');

    // De beheerder zelf heeft geen verwijderknop, Liam wel.
    expect(find.byTooltip('Papa verwijderen'), findsNothing);
    await tester.tap(find.byTooltip('Liam verwijderen'));
    await tester.pumpAndSettle();
    expect(find.text('Liam verwijderen?'), findsOneWidget);
    await tester.tap(find.widgetWithText(FilledButton, 'Verwijderen'));
    await tester.pumpAndSettle();

    verify(() => repo.removeMember('fam', 'liam')).called(1);
    expect(find.text('Liam is uit het gezin verwijderd.'), findsOneWidget);
  });

  testWidgets('annuleren verwijdert niemand', (tester) async {
    final repo = await pump(tester, me: 'papa');

    await tester.tap(find.byTooltip('Liam verwijderen'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Annuleren'));
    await tester.pumpAndSettle();

    verifyNever(() => repo.removeMember(any(), any()));
  });

  testWidgets('een gewoon lid kan niemand verwijderen', (tester) async {
    await pump(tester, me: 'liam');

    expect(find.byTooltip('Papa verwijderen'), findsNothing);
    expect(find.byTooltip('Liam verwijderen'), findsNothing);
  });
}
