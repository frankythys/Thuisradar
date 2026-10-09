import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:thuisradar/core/theme/app_theme.dart';
import 'package:thuisradar/features/family/application/family_providers.dart';
import 'package:thuisradar/features/family/presentation/family_setup_screen.dart';

Future<void> _pump(WidgetTester tester) => tester.pumpWidget(
  ProviderScope(
    overrides: [myFamilyProvider.overrideWith((ref) async => null)],
    child: MaterialApp(theme: AppTheme.light(), home: const FamilySetupScreen()),
  ),
);

void main() {
  testWidgets('vraagt hoe je wilt starten en toont eerst enkel het nieuwe-familie-formulier', (tester) async {
    await _pump(tester);
    expect(find.text('Hoe wil je starten?'), findsOneWidget);
    expect(find.text('Nieuwe familie'), findsOneWidget);
    expect(find.text('Ik heb een code'), findsOneWidget);
    expect(find.text('Familie aanmaken'), findsOneWidget);
    expect(find.text('Deelnemen aan familie'), findsNothing);
  });

  testWidgets('tik op "Ik heb een code" toont enkel het codeformulier', (tester) async {
    await _pump(tester);
    await tester.tap(find.text('Ik heb een code'));
    await tester.pumpAndSettle();
    expect(find.text('Deelnemen aan familie'), findsOneWidget);
    expect(find.text('Familie aanmaken'), findsNothing);
    expect(find.text('Plakken'), findsOneWidget);
  });

  testWidgets('past zonder scrollen op 360 × 640', (tester) async {
    tester.view.physicalSize = const Size(360, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await _pump(tester);
    for (final label in ['Familie aanmaken', 'Alleen wie je uitnodigt, ziet je op de kaart.']) {
      expect(tester.getBottomLeft(find.text(label)).dy, lessThan(640));
    }
  });
}
