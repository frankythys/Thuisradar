import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:thuisradar/core/theme/app_theme.dart';
import 'package:thuisradar/features/auth/presentation/login_screen.dart';

Future<void> _pump(WidgetTester tester) {
  return tester.pumpWidget(
    ProviderScope(
      child: MaterialApp(theme: AppTheme.light(), home: const LoginScreen()),
    ),
  );
}

void main() {
  setUp(() => FlutterSecureStorage.setMockInitialValues({}));
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
  });

  testWidgets('onthouden login wordt ingevuld met verborgen wachtwoord', (tester) async {
    FlutterSecureStorage.setMockInitialValues({
      'thuisradar_remembered_login': '{"email":"test@example.com","password":"test-password"}',
    });
    await _pump(tester);
    await tester.pumpAndSettle();
    final fields = tester.widgetList<TextFormField>(find.byType(TextFormField)).toList();
    expect(fields[0].controller!.text, 'test@example.com');
    expect(fields[1].controller!.text, 'test-password');
    expect(tester.widgetList<EditableText>(find.byType(EditableText)).last.obscureText, isTrue);
  });

  testWidgets('past op een telefoonscherm zonder te scrollen', (tester) async {
    // Samsung A52: 412 × 915 dp, min. status- en navigatiebalk.
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
