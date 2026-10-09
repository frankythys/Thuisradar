import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:thuisradar/core/theme/app_theme.dart';
import 'package:thuisradar/features/onboarding/application/onboarding_providers.dart';
import 'package:thuisradar/features/onboarding/data/onboarding_store.dart';
import 'package:thuisradar/features/onboarding/presentation/replay_onboarding_button.dart';

class _FakeStore extends OnboardingStore {
  bool seen = true;

  @override
  Future<bool> hasSeen() async => seen;

  @override
  Future<void> reset() async => seen = false;
}

void main() {
  testWidgets('knop zet onboarding terug en sluit het profielscherm', (tester) async {
    final store = _FakeStore();
    final container = ProviderContainer(overrides: [onboardingStoreProvider.overrideWithValue(store)]);
    addTearDown(container.dispose);
    expect(await container.read(onboardingSeenProvider.future), isTrue);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          theme: AppTheme.light(),
          home: Builder(
            builder: (context) => TextButton(
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute<void>(builder: (_) => const Scaffold(body: ReplayOnboardingButton())),
              ),
              child: const Text('Profiel'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Profiel'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Introductie opnieuw bekijken'));
    await tester.pumpAndSettle();

    expect(store.seen, isFalse);
    expect(await container.read(onboardingSeenProvider.future), isFalse);
    expect(find.byType(ReplayOnboardingButton), findsNothing);
  });
}
