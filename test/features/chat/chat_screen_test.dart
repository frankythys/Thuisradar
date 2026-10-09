import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:thuisradar/core/theme/app_theme.dart';
import 'package:thuisradar/features/auth/application/auth_providers.dart';
import 'package:thuisradar/features/chat/application/chat_providers.dart';
import 'package:thuisradar/features/chat/domain/message.dart';
import 'package:thuisradar/features/chat/presentation/chat_screen.dart';
import 'package:thuisradar/features/family/application/family_providers.dart';
import 'package:thuisradar/features/family/domain/family.dart';
import 'package:thuisradar/features/family/domain/family_member.dart';
import 'package:thuisradar/shared/widgets/member_avatar.dart';

const _family = Family(id: 'fam', name: 'Familie Thys', inviteCode: 'ABC12345');

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(
      const MethodChannel('com.llfbandit.record/messages'),
      (call) async => null,
    );
  });

  testWidgets('dagen als label, avatar bij anderen, mic wordt verzendknop en wissen zit in het menu', (
    tester,
  ) async {
    final now = DateTime.now();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          currentUserIdProvider.overrideWithValue('papa'),
          familyMembersProvider.overrideWith(
            (ref, id) => Stream.value(const [
              FamilyMember(userId: 'papa', displayName: 'Papa', isOwner: true, colorIndex: 0),
              FamilyMember(userId: 'liam', displayName: 'Liam', isOwner: false, colorIndex: 3),
            ]),
          ),
          familyMessagesProvider.overrideWith(
            (ref, id) => Stream.value([
              Message(
                id: 1,
                familyId: 'fam',
                userId: 'liam',
                body: 'Hallo',
                createdAt: now.subtract(const Duration(days: 1)),
              ),
              Message(id: 2, familyId: 'fam', userId: 'papa', body: 'Hoi', createdAt: now),
            ]),
          ),
        ],
        child: MaterialApp(
          theme: AppTheme.light(),
          home: const ChatScreen(family: _family),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Gisteren'), findsOneWidget);
    expect(find.text('Vandaag'), findsOneWidget);
    // Avatar naast het bericht van Liam (niet naast dat van mezelf).
    expect(find.widgetWithText(MemberAvatar, 'L'), findsOneWidget);

    expect(find.byTooltip('Spraakbericht opnemen'), findsOneWidget);
    await tester.enterText(find.byType(TextField), 'Tot straks');
    await tester.pump();
    expect(find.byTooltip('Versturen'), findsOneWidget);

    // Geen losse "Wissen"-knop meer in de balk; wel in het menu.
    expect(find.text('Wissen'), findsNothing);
    await tester.tap(find.byTooltip('Meer opties'));
    await tester.pumpAndSettle();
    expect(find.text('Chat wissen'), findsOneWidget);
    expect(find.text('Bel een gezinslid'), findsOneWidget);
  });
}
