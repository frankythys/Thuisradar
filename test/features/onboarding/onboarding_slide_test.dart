import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:thuisradar/features/language/domain/app_language.dart';
import 'package:thuisradar/features/onboarding/domain/onboarding_slide.dart';
import 'package:thuisradar/features/onboarding/presentation/onboarding_slides.dart';
import 'package:thuisradar/l10n/l10n.dart';

void main() {
  for (final language in AppLanguage.values) {
    test('${language.code}: vier slides, elk met eigen illustratie en volledige tekst', () {
      final slides = onboardingSlides(lookupAppLocalizations(Locale(language.code)));
      expect(slides, hasLength(4));
      expect(slides.map((s) => s.scene).toList(), OnboardingScene.values);
      for (final s in slides) {
        expect([s.eyebrow, s.title, s.body, s.reassurance], everyElement(isNotEmpty));
      }
    });
  }
}
