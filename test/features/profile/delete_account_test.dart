import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:thuisradar/core/theme/app_theme.dart';
import 'package:thuisradar/features/auth/application/auth_providers.dart';
import 'package:thuisradar/features/auth/data/account_deletion_repository.dart';
import 'package:thuisradar/features/family/application/family_providers.dart';
import 'package:thuisradar/features/family/data/family_repository.dart';
import 'package:thuisradar/features/family/domain/family.dart';
import 'package:thuisradar/features/family/domain/family_member.dart';
import 'package:thuisradar/features/profile/application/profile_providers.dart';
import 'package:thuisradar/features/profile/presentation/profile_screen.dart';

class _FamilyRepo extends Mock implements FamilyRepository {}

class _Deletion extends Mock implements AccountDeletionRepository {}

const _family = Family(id: 'fam', name: 'Familie Thys', inviteCode: 'K7Q2M9XA');

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  Future<_Deletion> pump(WidgetTester tester, {required String me}) async {
    final familyRepo = _FamilyRepo();
    final deletion = _Deletion();
    when(() => familyRepo.fetchInvite('fam')).thenAnswer((_) async => _family);
    tester.view.physicalSize = const Size(1080, 2240);
    tester.view.devicePixelRatio = 2.625;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          familyRepositoryProvider.overrideWithValue(familyRepo),
          accountDeletionRepositoryProvider.overrideWithValue(deletion),
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
    await tester.scrollUntilVisible(find.text('Account verwijderen'), 200);
    await tester.tap(find.text('Account verwijderen'));
    await tester.pumpAndSettle();
    return deletion;
  }

  testWidgets('de beheerder draagt eerst het beheer over', (tester) async {
    final deletion = await pump(tester, me: 'papa');

    expect(find.text('Account verwijderen?'), findsNothing);
    expect(find.textContaining('je account verwijderen'), findsOneWidget);
    verifyNever(deletion.deleteMyAccount);
  });

  testWidgets('annuleren wist niets', (tester) async {
    final deletion = await pump(tester, me: 'liam');

    expect(find.text('Account verwijderen?'), findsOneWidget);
    await tester.tap(find.text('Annuleren'));
    await tester.pumpAndSettle();

    verifyNever(deletion.deleteMyAccount);
  });

  testWidgets('verwijderen mislukt: een melding, en je blijft ingelogd op het scherm', (tester) async {
    final deletion = await pump(tester, me: 'liam');
    when(deletion.deleteMyAccount).thenThrow(const PostgrestException(message: 'offline'));

    await tester.tap(find.widgetWithText(FilledButton, 'Definitief verwijderen'));
    await tester.pumpAndSettle();

    verify(deletion.deleteMyAccount).called(1);
    expect(find.text('Account verwijderen is niet gelukt. Probeer opnieuw.'), findsOneWidget);
    expect(find.byType(ProfileScreen), findsOneWidget);
  });

  testWidgets('de server weigert de beheerder: dezelfde uitleg als in de app', (tester) async {
    final deletion = await pump(tester, me: 'liam');
    when(deletion.deleteMyAccount)
        .thenThrow(const PostgrestException(message: 'Draag eerst het beheer over aan een ander gezinslid'));

    await tester.tap(find.widgetWithText(FilledButton, 'Definitief verwijderen'));
    await tester.pumpAndSettle();

    expect(find.textContaining('je account verwijderen'), findsOneWidget);
  });
}
