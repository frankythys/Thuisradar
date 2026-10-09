/// Welke illustratie bovenaan een slide staat.
enum OnboardingScene { map, privacy, alerts, sos }

/// Eén onboarding-slide: puur gegeven, zonder Flutter.
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

/// De vier slides, in volgorde.
const onboardingSlides = <OnboardingSlide>[
  OnboardingSlide(
    scene: OnboardingScene.map,
    eyebrow: 'Live kaart',
    title: 'Zie in één oogopslag waar iedereen is',
    body: 'Jullie gezin op één kaart, live bijgewerkt. Geen telefoontjes meer om te vragen waar iemand is.',
    reassurance: 'Zuinig voor je batterij',
  ),
  OnboardingSlide(
    scene: OnboardingScene.privacy,
    eyebrow: 'Privacy',
    title: 'Alleen jullie gezin kijkt mee',
    body: 'Locaties zijn enkel zichtbaar binnen jullie eigen kring. Niemand anders, ook wij niet.',
    reassurance: 'Je bepaalt zelf wie in je kring zit',
  ),
  OnboardingSlide(
    scene: OnboardingScene.alerts,
    eyebrow: 'Meldingen',
    title: 'Een seintje als iemand aankomt',
    body: 'Automatisch bericht bij vertrek en aankomst op vertrouwde plekken zoals Thuis, School of Werk.',
    reassurance: 'Per plek aan of uit te zetten',
  ),
  OnboardingSlide(
    scene: OnboardingScene.sos,
    eyebrow: 'Noodknop',
    title: 'Hulp met één knop',
    body: 'Houd de noodknop 3 seconden vast en het hele gezin krijgt meteen een alarm met je live-locatie.',
    reassurance: 'Geen vals alarm door per ongeluk tikken',
  ),
];
