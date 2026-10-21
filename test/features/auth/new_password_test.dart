import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:thuisradar/core/theme/app_theme.dart';
import 'package:thuisradar/features/auth/application/auth_providers.dart';
import 'package:thuisradar/features/auth/data/auth_repository.dart';
import 'package:thuisradar/features/auth/presentation/new_password_screen.dart';

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

  test('de herstellink zet het scherm Nieuw wachtwoord aan, finish zet het af', () async {
    final container = ProviderContainer(overrides: [authRepositoryProvider.overrideWithValue(auth)]);
    addTearDown(container.dispose);

    expect(container.read(passwordRecoveryProvider), isFalse);
    recovery.add(null);
    await pumpEventQueue();
    expect(container.read(passwordRecoveryProvider), isTrue);

    container.read(passwordRecoveryProvider.notifier).finish();
    expect(container.read(passwordRecoveryProvider), isFalse);
  });

  group('scherm Nieuw wachtwoord', () {
    late ProviderContainer container;

    Future<void> pump(WidgetTester tester) async {
      container = ProviderContainer(overrides: [authRepositoryProvider.overrideWithValue(auth)]);
      addTearDown(container.dispose);
      // Zoals AuthGate: de provider luistert al vóór de herstellink binnenkomt.
      container.read(passwordRecoveryProvider);
      recovery.add(null);
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp(theme: AppTheme.light(), home: const NewPasswordScreen()),
        ),
      );
      await tester.pumpAndSettle();
    }

    Future<void> fill(WidgetTester tester, String password, String repeat) async {
      final fields = find.byType(TextFormField);
      await tester.enterText(fields.at(0), password);
      await tester.enterText(fields.at(1), repeat);
      await tester.tap(find.text('Wachtwoord opslaan'));
      await tester.pumpAndSettle();
    }

    testWidgets('twee verschillende wachtwoorden: niets opgeslagen', (tester) async {
      await pump(tester);
      await fill(tester, 'Geheim-123', 'Geheim-124');
      expect(find.text('De wachtwoorden zijn niet gelijk.'), findsOneWidget);
      verifyNever(() => auth.updatePassword(any()));
    });

    testWidgets('opslaan lukt: wachtwoord gezet en verder naar de app', (tester) async {
      when(() => auth.updatePassword(any())).thenAnswer((_) async {});
      await pump(tester);
      expect(container.read(passwordRecoveryProvider), isTrue);

      await fill(tester, 'Geheim-123', 'Geheim-123');

      verify(() => auth.updatePassword('Geheim-123')).called(1);
      expect(container.read(passwordRecoveryProvider), isFalse);
    });

    testWidgets('te zwak volgens Supabase: uitleg in de app-taal', (tester) async {
      when(() => auth.updatePassword(any()))
          .thenThrow(AuthWeakPasswordException(message: 'weak', statusCode: '422', reasons: const []));
      await pump(tester);
      await fill(tester, 'geheim123', 'geheim123');
      expect(find.textContaining('te zwak'), findsOneWidget);
      expect(container.read(passwordRecoveryProvider), isTrue);
    });

    testWidgets('zelfde als het oude wachtwoord: duidelijke melding', (tester) async {
      when(() => auth.updatePassword(any()))
          .thenThrow(const AuthApiException('same', statusCode: '422', code: 'same_password'));
      await pump(tester);
      await fill(tester, 'Geheim-123', 'Geheim-123');
      expect(find.text('Kies een ander wachtwoord dan je vorige.'), findsOneWidget);
    });

    testWidgets('Later: verder naar de app zonder iets te wijzigen', (tester) async {
      await pump(tester);
      await tester.tap(find.text('Later'));
      await tester.pumpAndSettle();
      expect(container.read(passwordRecoveryProvider), isFalse);
      verifyNever(() => auth.updatePassword(any()));
    });
  });
}
