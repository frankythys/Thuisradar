import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:thuisradar/core/theme/app_theme.dart';
import 'package:thuisradar/features/onboarding/application/onboarding_providers.dart';
import 'package:thuisradar/features/onboarding/data/onboarding_store.dart';
import 'package:thuisradar/features/onboarding/presentation/onboarding_screen.dart';

class _FakeStore extends OnboardingStore {
  bool seen = false;

  @override
  Future<bool> hasSeen() async => seen;

  @override
  Future<void> markSeen() async => seen = true;
}

Future<void> _pump(WidgetTester tester, _FakeStore store) {
  return tester.pumpWidget(
    ProviderScope(
      overrides: [onboardingStoreProvider.overrideWithValue(store)],
      child: MaterialApp(theme: AppTheme.light(), home: const OnboardingScreen()),
    ),
  );
}

void main() {
  testWidgets('doorloopt de slides en rondt af met Aan de slag', (tester) async {
    final store = _FakeStore();
    await _pump(tester, store);

    expect(find.text('Altijd weten dat iedereen veilig thuis is'), findsOneWidget);
    expect(find.text('Volgende'), findsOneWidget);

    for (var i = 0; i < 3; i++) {
      await tester.tap(find.text('Volgende'));
      await tester.pumpAndSettle();
    }

    expect(find.text('Aan de slag'), findsOneWidget);
    await tester.tap(find.text('Aan de slag'));
    await tester.pump();
    expect(store.seen, isTrue);
  });

  testWidgets('Overslaan markeert de onboarding als gezien', (tester) async {
    final store = _FakeStore();
    await _pump(tester, store);

    await tester.tap(find.text('Overslaan'));
    await tester.pump();
    expect(store.seen, isTrue);
  });
}
