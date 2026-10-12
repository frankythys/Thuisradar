import 'package:flutter/material.dart';
import 'package:mocktail/mocktail.dart';
import 'package:thuisradar/features/auth/data/auth_repository.dart';
import 'package:thuisradar/features/auth/application/auth_providers.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:thuisradar/core/theme/app_theme.dart';
import 'package:thuisradar/features/auth/presentation/login_screen.dart';

class _GoogleAuth extends Mock implements AuthRepository {}

Future<void> _pump(WidgetTester tester) {
  return tester.pumpWidget(
    ProviderScope(
      child: MaterialApp(theme: AppTheme.light(), home: const LoginScreen()),
    ),
  );
}

void main() {
  setUp(() => FlutterSecureStorage.setMockInitialValues({}));
  testWidgets('Google-login werkt zonder ingevulde e-mail of wachtwoord', (tester) async {
    final auth = _GoogleAuth();
    when(() => auth.signInWithGoogle()).thenAnswer((_) async {});
    await tester.pumpWidget(
      ProviderScope(
        overrides: [authRepositoryProvider.overrideWithValue(auth)],
        child: MaterialApp(theme: AppTheme.light(), home: const LoginScreen()),
      ),
    );
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Doorgaan met Google'));
    await tester.tap(find.text('Doorgaan met Google'));
    await tester.pumpAndSettle();
    verify(() => auth.signInWithGoogle()).called(1);
    expect(find.text('Ongeldig e-mailadres'), findsNothing);
    expect(find.text('Minstens 8 tekens'), findsNothing);
  });

  testWidgets('Google-startfout toont een melding en maakt opnieuw proberen mogelijk', (tester) async {
    final auth = _GoogleAuth();
    when(() => auth.signInWithGoogle()).thenThrow(StateError('Browser niet beschikbaar'));
    await tester.pumpWidget(
      ProviderScope(
        overrides: [authRepositoryProvider.overrideWithValue(auth)],
        child: MaterialApp(theme: AppTheme.light(), home: const LoginScreen()),
      ),
    );
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Doorgaan met Google'));
    await tester.tap(find.text('Doorgaan met Google'));
    await tester.pumpAndSettle();
    expect(find.text('Google-login kon niet worden gestart. Probeer opnieuw.'), findsOneWidget);
    final button = tester.widget<OutlinedButton>(find.widgetWithText(OutlinedButton, 'Doorgaan met Google'));
    expect(button.onPressed, isNotNull);
  });

  testWidgets('start in inlog-modus zonder naamveld', (tester) async {
    await _pump(tester);

    expect(find.text('Welkom terug'), findsOneWidget);
    expect(find.text('Naam'), findsNothing);
  });

  testWidgets('wisselt naar registreren en toont het naamveld', (tester) async {
    await _pump(tester);

    await tester.ensureVisible(find.text('Nieuw? Maak een account'));
    await tester.tap(find.text('Nieuw? Maak een account'));
    await tester.pumpAndSettle();

    expect(find.text('Maak je account'), findsOneWidget);
    expect(find.text('Naam'), findsOneWidget);
    expect(find.text('Account aanmaken'), findsOneWidget);
    expect(find.text('Doorgaan met Google'), findsOneWidget);
  });

  testWidgets('onthouden vult enkel het e-mailadres in, nooit het wachtwoord', (tester) async {
    // Een oudere versie bewaarde ook het wachtwoord.
    FlutterSecureStorage.setMockInitialValues({
      'thuisradar_remembered_login': '{"email":"test@example.com","password":"test-password"}',
    });
    await _pump(tester);
    await tester.pumpAndSettle();
    final fields = tester.widgetList<TextFormField>(find.byType(TextFormField)).toList();
    expect(fields[0].controller!.text, 'test@example.com');
    expect(fields[1].controller!.text, isEmpty);
    // Het oude wachtwoord is meteen uit de opslag gewist.
    final stored = await const FlutterSecureStorage().read(key: 'thuisradar_remembered_login');
    expect(stored, isNot(contains('test-password')));
  });

  testWidgets('past op een telefoonscherm zonder te scrollen', (tester) async {
    // Samsung A52: 412 Ã— 915 dp, min. status- en navigatiebalk.
    tester.view.physicalSize = const Size(412, 860);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await _pump(tester);
    await tester.pumpAndSettle();

    final screen = tester.getRect(find.byType(Scaffold));
    for (final label in ['Inloggen', 'Nieuw? Maak een account']) {
      final rect = tester.getRect(find.text(label));
      expect(screen.contains(rect.bottomRight - const Offset(1, 1)), isTrue, reason: label);
    }
    expect(find.byTooltip('Inloggen met biometrie'), findsOneWidget);
    expect(find.text('OF'), findsNothing);
  });
}
