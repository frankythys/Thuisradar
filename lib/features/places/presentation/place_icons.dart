import 'package:flutter/material.dart';

/// Vaste set plaats-iconen (sleutel = `places.icon`).
const placeIconKeys = ['home', 'school', 'work', 'sports', 'store', 'place'];

IconData placeIcon(String key) => switch (key) {
  'home' => Icons.home_rounded,
  'school' => Icons.school_outlined,
  'work' => Icons.work_outline,
  'sports' => Icons.sports_soccer,
  'store' => Icons.store_outlined,
  _ => Icons.place_outlined,
};
