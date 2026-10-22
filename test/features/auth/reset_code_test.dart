import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:thuisradar/core/theme/app_theme.dart';
import 'package:thuisradar/features/auth/application/auth_providers.dart';
import 'package:thuisradar/features/auth/data/auth_repository.dart';
import 'package:thuisradar/features/auth/presentation/reset_code_screen.dart';

class _Auth extends Mock implements AuthRepository {}

void main() {
  late _Auth auth;
  late StreamController<void> recovery;

  setUp(() {
    auth = _Auth();
    recovery = StreamController<void>.broadcast();
    when(() => auth.watchPasswordRecovery()).thenAnswer((_) => recovery.stream);
  });
  tearDown(() => recovery.close());

  /// Het codescherm bovenop een "loginscherm", zoals na Wachtwoord vergeten.
  Future<ProviderContainer> pump(WidgetTester tester) async {
    final container = ProviderContainer(overrides: [authRepositoryProvider.overrideWithValue(auth)]);
    addTearDown(container.dispose);
    container.read(passwordRecoveryProvider); // zoals AuthGate: luistert van bij de start
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          theme: AppTheme.light(),
          home: Builder(
            builder: (context) => Scaffold(
              body: TextButton(
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute<void>(builder: (_) => const ResetCodeScreen(email: 'oma@example.com')),
                ),
                child: const Text('login'),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('login'));
    await tester.pumpAndSettle();
    return container;
  }

  testWidgets('toont naar welk adres de mail ging', (tester) async {
    await pump(tester);
    expect(find.textContaining('oma@example.com'), findsOneWidget);
  });

  testWidgets('juiste code: gecontroleerd, en het scherm sluit bij het herstel-event', (tester) async {
    when(
      () => auth.verifyRecoveryCode(
        email: any(named: 'email'),
        code: any(named: 'code'),
      ),
    ).thenAnswer((_) async => recovery.add(null));
    await pump(tester);

    await tester.enterText(find.byType(TextField), '123456');
    await tester.tap(find.text('Bevestigen'));
    await tester.pumpAndSettle();

    verify(() => auth.verifyRecoveryCode(email: 'oma@example.com', code: '123456')).called(1);
    expect(find.byType(ResetCodeScreen), findsNothing);
    expect(find.text('login'), findsOneWidget);
  });

  testWidgets('foute of verlopen code: uitleg, en het scherm blijft', (tester) async {
    when(
      () => auth.verifyRecoveryCode(
        email: any(named: 'email'),
        code: any(named: 'code'),
      ),
    ).thenThrow(
      const AuthApiException('Token has expired or is invalid', statusCode: '403', code: 'otp_expired'),
    );
    await pump(tester);

    await tester.enterText(find.byType(TextField), '654321');
    await tester.tap(find.text('Bevestigen'));
    await tester.pumpAndSettle();

    expect(find.textContaining('klopt niet of is verlopen'), findsOneWidget);
    expect(find.byType(ResetCodeScreen), findsOneWidget);
  });

  testWidgets('te korte code of letters: niets naar de server', (tester) async {
    await pump(tester);
    await tester.enterText(find.byType(TextField), '12ab');
    await tester.tap(find.text('Bevestigen'));
    await tester.pumpAndSettle();
    verifyNever(
      () => auth.verifyRecoveryCode(
        email: any(named: 'email'),
        code: any(named: 'code'),
      ),
    );
  });

  testWidgets('de knop in de mail op deze gsm: het codescherm sluit vanzelf', (tester) async {
    await pump(tester);
    recovery.add(null);
    await tester.pumpAndSettle();
    expect(find.byType(ResetCodeScreen), findsNothing);
  });
}
