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

    expect(find.text('Zie in één oogopslag waar iedereen is'), findsOneWidget);
    expect(find.byTooltip('Volgende'), findsOneWidget);

    for (var i = 0; i < 3; i++) {
      await tester.tap(find.byTooltip('Volgende'));
      await tester.pumpAndSettle();
    }

    expect(find.text('Aan de slag'), findsOneWidget);
    await tester.tap(find.text('Aan de slag'));
    await tester.pump();
    expect(store.seen, isTrue);
  });

  testWidgets('afbreken voor de laatste stap rondt onboarding niet af', (tester) async {
    final store = _FakeStore();
    await _pump(tester, store);

    await tester.tap(find.text('Overslaan'));
    await tester.pumpAndSettle();
    expect(find.text('Aan de slag'), findsOneWidget);
    expect(find.text('Overslaan'), findsNothing);
    expect(store.seen, isFalse);
    await tester.pumpWidget(const SizedBox.shrink());
    await _pump(tester, store);
    expect(find.text('Zie in één oogopslag waar iedereen is'), findsOneWidget);
    expect(store.seen, isFalse);
  });

  for (final size in const [Size(412, 860), Size(360, 640)]) {
    testWidgets('alle slides passen zonder overloop op $size', (tester) async {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await _pump(tester, _FakeStore());

      for (var i = 0; i < 3; i++) {
        await tester.tap(find.byTooltip('Volgende'));
        await tester.pumpAndSettle();
      }
      expect(find.text('Aan de slag'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }
}
