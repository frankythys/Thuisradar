import 'package:flutter/material.dart';

/// Eén onboarding-slide: puur gegeven, zonder Flutter-logica buiten het icoon.
@immutable
class OnboardingSlide {
  const OnboardingSlide({
    required this.icon,
    required this.illustrationBase,
    required this.title,
    required this.body,
    this.footnoteTitle,
    this.footnote,
  });

  final IconData icon;

  /// Pad zonder extensie, bv. `assets/illustrations/onboarding_1`. De hero zoekt
  /// hier een `.png` of `.svg` bij; ontbreekt die, dan toont hij het [icon].
  final String illustrationBase;

  final String title;
  final String body;

  /// Optionele uitgelichte belofte onderaan de slide (bv. privacy).
  final String? footnoteTitle;
  final String? footnote;
}

/// De vier slides, tekst letterlijk uit de Stitch-mockups.
const onboardingSlides = <OnboardingSlide>[
  OnboardingSlide(
    icon: Icons.home_rounded,
    illustrationBase: 'assets/illustrations/onboarding_1',
    title: 'Altijd weten dat iedereen veilig thuis is',
    body: 'Een gerust hart voor het hele gezin. Deel elkaars veilige aankomst zonder gedoe of controlesfeer.',
    footnoteTitle: 'Privacy op de eerste plaats',
    footnote: 'Enkel zichtbaar voor jullie eigen veilige familiekring.',
  ),
  OnboardingSlide(
    icon: Icons.verified_user_rounded,
    illustrationBase: 'assets/illustrations/onboarding_2',
    title: 'Alleen voor je familie',
    body:
        'Jullie locaties zijn uitsluitend zichtbaar binnen jullie eigen familiekring. '
        'Geen trackers, nooit verkocht of gedeeld.',
    footnoteTitle: 'End-to-end beveiligd',
    footnote: 'Alleen gezinsleden hebben toegang. Geen advertenties.',
  ),
  OnboardingSlide(
    icon: Icons.notifications_active_rounded,
    illustrationBase: 'assets/illustrations/onboarding_3',
    title: 'Meldingen als het telt',
    body:
        'Automatische seintjes bij vertrek en aankomst op vertrouwde plekken '
        'zoals Thuis, School of Werk.',
  ),
  OnboardingSlide(
    icon: Icons.emergency_rounded,
    illustrationBase: 'assets/illustrations/onboarding_4',
    title: 'Hulp met één knop',
    body:
        'In noodgevallen stuurt de noodknop direct een discreet alarmsignaal '
        'met je exacte live-locatie naar het hele gezin.',
  ),
];
