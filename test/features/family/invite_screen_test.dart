import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:thuisradar/core/theme/app_theme.dart';
import 'package:thuisradar/features/family/domain/family.dart';
import 'package:thuisradar/features/family/presentation/invite_screen.dart';

void main() {
  const channel = MethodChannel('dev.fluttercommunity.plus/share');
  const family = Family(id: 'fam', name: 'Ons gezin', inviteCode: 'ABC12345');

  testWidgets('Verzenden deelt de getoonde code via de systeemkiezer', (
    tester,
  ) async {
    MethodCall? shared;
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(channel, (
      call,
    ) async {
      shared = call;
      return 'dev.fluttercommunity.plus/share/dismissed';
    });
    addTearDown(
      () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        channel,
        null,
      ),
    );

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        home: const InviteScreen(family: family),
      ),
    );
    expect(find.text('A B C 1 2 3 4 5'), findsOneWidget);
    await tester.ensureVisible(find.text('Verzenden'));
    await tester.tap(find.text('Verzenden'));
    await tester.pumpAndSettle();

    expect(shared?.method, 'share');
    expect(shared?.arguments['text'], contains('ABC12345'));
    expect(shared?.arguments['text'], contains('Ons gezin'));
    expect(shared?.arguments['originWidth'], greaterThan(0));
    expect(find.byType(SnackBar), findsNothing);
  });

  testWidgets('mislukt delen biedt kopiëren als alternatief', (tester) async {
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(channel, (
      _,
    ) async {
      throw PlatformException(code: 'unavailable');
    });
    addTearDown(
      () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        channel,
        null,
      ),
    );
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        home: const InviteScreen(family: family),
      ),
    );
    await tester.ensureVisible(find.text('Verzenden'));
    await tester.tap(find.text('Verzenden'));
    await tester.pumpAndSettle();
    expect(
      find.text('Verzenden lukt niet. Probeer opnieuw of kopieer de code.'),
      findsOneWidget,
    );
  });
}
