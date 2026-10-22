import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:thuisradar/core/theme/app_theme.dart';
import 'package:thuisradar/core/utils/clock.dart';
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

  /// Opent Profiel › Gezin als [me].
  Future<_Repo> pump(WidgetTester tester, {required String me}) async {
    final repo = _Repo();
    var invite = _family;
    when(() => repo.fetchInvite('fam')).thenAnswer((_) async => invite);
    when(() => repo.renameFamily('fam', any())).thenAnswer((call) async {
      invite = Family(id: 'fam', name: call.positionalArguments[1] as String, inviteCode: 'K7Q2M9XA');
      return invite;
    });
    tester.view.physicalSize = const Size(1080, 2240);
    tester.view.devicePixelRatio = 2.625;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          familyRepositoryProvider.overrideWithValue(repo),
          clockProvider.overrideWith((ref) => Stream.value(DateTime(2026, 10, 22, 12))),
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
        child: MaterialApp(theme: AppTheme.light(), home: const ProfileScreen(family: _family)),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Familie Thys'));
    await tester.pumpAndSettle();
    return repo;
  }

  Future<void> rename(WidgetTester tester, String name) async {
    await tester.tap(find.text('Gezinsnaam wijzigen'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), name);
    await tester.tap(find.widgetWithText(FilledButton, 'Opslaan'));
    await tester.pumpAndSettle();
  }

  testWidgets('de beheerder wijzigt de gezinsnaam; het profiel toont meteen de nieuwe', (tester) async {
    final repo = await pump(tester, me: 'papa');

    await rename(tester, '  Thys-Creve ');

    verify(() => repo.renameFamily('fam', 'Thys-Creve')).called(1);
    expect(find.text('Gezinsnaam gewijzigd.'), findsOneWidget);
    expect(find.text('Thys-Creve'), findsOneWidget);
    expect(find.text('Familie Thys'), findsNothing);
  });

  testWidgets('een lege naam wordt niet bewaard', (tester) async {
    final repo = await pump(tester, me: 'papa');

    await rename(tester, '   ');

    expect(find.text('Vul een gezinsnaam in.'), findsOneWidget);
    verifyNever(() => repo.renameFamily(any(), any()));
  });

  testWidgets('dezelfde naam opnieuw: niets naar de server', (tester) async {
    final repo = await pump(tester, me: 'papa');

    await rename(tester, 'Familie Thys');

    verifyNever(() => repo.renameFamily(any(), any()));
  });

  testWidgets('een gewoon lid ziet geen knop om de naam te wijzigen', (tester) async {
    await pump(tester, me: 'liam');

    expect(find.text('Gezinsnaam wijzigen'), findsNothing);
  });
}
