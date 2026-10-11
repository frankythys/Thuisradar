import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:thuisradar/core/theme/app_theme.dart';
import 'package:thuisradar/features/auth/application/auth_providers.dart';
import 'package:thuisradar/features/family/application/family_providers.dart';
import 'package:thuisradar/features/family/data/family_repository.dart';
import 'package:thuisradar/features/family/domain/family.dart';
import 'package:thuisradar/features/family/domain/family_member.dart';
import 'package:thuisradar/features/family/presentation/invite_screen.dart';

class _Repo extends Mock implements FamilyRepository {}

void main() {
  final now = DateTime(2026, 10, 11, 16);
  final valid = Family(
    id: 'fam',
    name: 'Ons gezin',
    inviteCode: 'ABC12345',
    inviteExpiresAt: DateTime(2026, 10, 18, 14, 5),
  );

  test('Family leest de vervaldatum, en mist ze zonder migratie 017', () {
    final withExpiry = Family.fromJson({
      'id': 'f',
      'name': 'G',
      'invite_code': 'X',
      'invite_expires_at': '2026-10-18T12:05:00+00:00',
    });
    expect(withExpiry.inviteExpiresAt, DateTime.utc(2026, 10, 18, 12, 5).toLocal());
    expect(Family.fromJson({'id': 'f', 'name': 'G', 'invite_code': 'X'}).inviteExpiresAt, isNull);
  });

  test('geldigheid: datum, verlopen (beheerder of lid) of onbekend', () {
    expect(inviteValidity(valid, now, isOwner: true), 'Geldig tot 18/10 om 14:05');
    final expired = Family(id: 'f', name: 'G', inviteCode: 'X', inviteExpiresAt: DateTime(2026, 10, 1));
    expect(inviteValidity(expired, now, isOwner: true), contains('Maak een nieuwe code'));
    expect(inviteValidity(expired, now, isOwner: false), contains('Vraag de beheerder'));
    expect(inviteValidity(const Family(id: 'f', name: 'G', inviteCode: 'X'), now, isOwner: true), isNull);
  });

  Future<_Repo> pump(WidgetTester tester, {required bool owner}) async {
    final repo = _Repo();
    var current = valid;
    when(() => repo.fetchInvite('fam')).thenAnswer((_) async => current);
    when(() => repo.rotateInviteCode('fam')).thenAnswer((_) async {
      current = Family(
        id: 'fam',
        name: 'Ons gezin',
        inviteCode: 'NEW98765',
        inviteExpiresAt: DateTime(2026, 10, 25, 9),
      );
      return current;
    });
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 2.625;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          familyRepositoryProvider.overrideWithValue(repo),
          currentUserIdProvider.overrideWithValue('papa'),
          familyMembersProvider.overrideWith(
            (ref, id) => Stream.value([
              FamilyMember(userId: 'papa', displayName: 'Papa', isOwner: owner, colorIndex: 0),
            ]),
          ),
        ],
        child: MaterialApp(
          theme: AppTheme.light(),
          home: InviteScreen(family: valid.copyWithCode('ABC12345')),
        ),
      ),
    );
    await tester.pumpAndSettle();
    return repo;
  }

  testWidgets('de beheerder maakt een nieuwe code; de nieuwe code verschijnt', (tester) async {
    final repo = await pump(tester, owner: true);

    expect(find.text('Geldig tot 18/10 om 14:05'), findsOneWidget);
    await tester.ensureVisible(find.text('Nieuwe code maken'));
    await tester.tap(find.text('Nieuwe code maken'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Nieuwe code'));
    await tester.pumpAndSettle();

    verify(() => repo.rotateInviteCode('fam')).called(1);
    expect(find.text('N E W 9 8 7 6 5'), findsOneWidget);
    expect(find.text('Nieuwe code gemaakt. De oude werkt niet meer.'), findsOneWidget);
  });

  testWidgets('een gewoon lid ziet geen knop om de code te vernieuwen', (tester) async {
    await pump(tester, owner: false);

    expect(find.text('Nieuwe code maken'), findsNothing);
    expect(find.text('A B C 1 2 3 4 5'), findsOneWidget);
  });
}

extension on Family {
  Family copyWithCode(String code) =>
      Family(id: id, name: name, inviteCode: code, inviteExpiresAt: inviteExpiresAt);
}
