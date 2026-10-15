import 'package:flutter/material.dart';

import '../../../l10n/l10n.dart';

/// Vaste set plaats-iconen (sleutel = `places.icon`).
const placeIconKeys = ['home', 'school', 'work', 'sports', 'store', 'daycare', 'park', 'refinery', 'place'];

IconData placeIcon(String key) => switch (key) {
  'home' => Icons.home_rounded,
  'school' => Icons.school_outlined,
  'work' => Icons.work_outline,
  'sports' => Icons.sports_soccer,
  'store' => Icons.store_outlined,
  'daycare' => Icons.child_care,
  'park' => Icons.park_outlined,
  'refinery' => Icons.factory_outlined,
  _ => Icons.place_outlined,
};

String placeIconLabel(AppLocalizations l10n, String key) => switch (key) {
  'home' => l10n.placeIconHome,
  'school' => l10n.placeIconSchool,
  'work' => l10n.placeIconWork,
  'sports' => l10n.placeIconSports,
  'store' => l10n.placeIconStore,
  'daycare' => l10n.placeIconDaycare,
  'park' => l10n.placeIconPark,
  'refinery' => l10n.placeIconRefinery,
  _ => l10n.placeIconOther,
};
