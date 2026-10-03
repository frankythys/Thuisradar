import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
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
  testWidgets('start in inlog-modus zonder naamveld', (tester) async {
    await _pump(tester);

    expect(find.text('Welkom terug'), findsOneWidget);
    expect(find.text('Naam'), findsNothing);
  });

  testWidgets('wisselt naar registreren en toont het naamveld', (tester) async {
    await _pump(tester);

    await tester.tap(find.text('Nieuw? Maak een account'));
    await tester.pumpAndSettle();

    expect(find.text('Maak je account'), findsOneWidget);
    expect(find.text('Naam'), findsOneWidget);
    expect(find.text('Account aanmaken'), findsOneWidget);
  });
}
