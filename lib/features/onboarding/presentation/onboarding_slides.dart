import '../../../l10n/l10n.dart';
import '../domain/onboarding_slide.dart';

/// De vier slides in de taal van de app, in de volgorde van [OnboardingScene].
List<OnboardingSlide> onboardingSlides(AppLocalizations l10n) => [
  for (final scene in OnboardingScene.values)
    switch (scene) {
      OnboardingScene.map => OnboardingSlide(
        scene: scene,
        eyebrow: l10n.onboardingMapEyebrow,
        title: l10n.onboardingMapTitle,
        body: l10n.onboardingMapBody,
        reassurance: l10n.onboardingMapReassurance,
      ),
      OnboardingScene.privacy => OnboardingSlide(
        scene: scene,
        eyebrow: l10n.onboardingPrivacyEyebrow,
        title: l10n.onboardingPrivacyTitle,
        body: l10n.onboardingPrivacyBody,
        reassurance: l10n.onboardingPrivacyReassurance,
      ),
      OnboardingScene.alerts => OnboardingSlide(
        scene: scene,
        eyebrow: l10n.onboardingAlertsEyebrow,
        title: l10n.onboardingAlertsTitle,
        body: l10n.onboardingAlertsBody,
        reassurance: l10n.onboardingAlertsReassurance,
      ),
      OnboardingScene.sos => OnboardingSlide(
        scene: scene,
        eyebrow: l10n.onboardingSosEyebrow,
        title: l10n.onboardingSosTitle,
        body: l10n.onboardingSosBody,
        reassurance: l10n.onboardingSosReassurance,
      ),
    },
];
