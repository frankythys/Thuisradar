import 'package:flutter_test/flutter_test.dart';
import 'package:thuisradar/features/onboarding/domain/onboarding_slide.dart';

void main() {
  test('vier slides, elk met een eigen illustratie', () {
    expect(onboardingSlides, hasLength(4));
    expect(onboardingSlides.map((s) => s.scene).toSet(), OnboardingScene.values.toSet());
  });

  test('elke slide heeft label, titel, uitleg en geruststelling', () {
    for (final s in onboardingSlides) {
      expect([s.eyebrow, s.title, s.body, s.reassurance], everyElement(isNotEmpty));
    }
  });
}
