/// Welke illustratie bovenaan een slide staat.
enum OnboardingScene { map, privacy, alerts, sos }

/// Eén onboarding-slide: puur gegeven, zonder Flutter. De teksten komen uit
/// de vertalingen (`presentation/onboarding_slides.dart`); de volgorde volgt
/// [OnboardingScene].
class OnboardingSlide {
  const OnboardingSlide({
    required this.scene,
    required this.eyebrow,
    required this.title,
    required this.body,
    required this.reassurance,
  });

  final OnboardingScene scene;

  /// Kort label boven de titel, bv. "Privacy".
  final String eyebrow;
  final String title;
  final String body;

  /// Eén geruststellende regel onder de uitleg.
  final String reassurance;
}
