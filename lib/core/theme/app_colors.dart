import 'package:flutter/material.dart';

/// Kleuren uit het ontwerp (Thuisradar · Android schermen), palet "Oceaan":
/// fris blauwgroen op een neutrale, lichtgrijze achtergrond.
abstract final class AppColors {
  static const primary = Color(0xFF0A6F91);
  static const primaryContainer = Color(0xFF13809F);
  static const primarySoft = Color(0xFFDFF1F6);

  /// Iets sterkere tint voor actieve chips en secundaire knoppen.
  static const primaryTint = Color(0xFFC4E5EF);
  static const secondary = Color(0xFF633FCD);
  static const alert = Color(0xFFB4370A);

  /// Lichte oranje tint achter lage-batterij-pills en SOS-badges.
  static const alertSoft = Color(0xFFF7E0D4);
  static const ink = Color(0xFF0F1E24);
  static const muted = Color(0xFF51646B);
  static const ground = Color(0xFFF4F7F8);
  static const surfaceLow = Color(0xFFE8F0F3);
  static const border = Color(0xFFCFDDE2);

  /// Alleen voor kaartselectie; bewust geen kiesbare profielkleur.
  static const mapSelection = Color(0xFF762EEA);

  /// Vaste kleur per gezinslid, op volgorde van toetreden.
  static const members = [
    Color(0xFF0E6E5C),
    // De oude paarse optie is grijs; opgeslagen kleurindexen blijven stabiel.
    Color(0xFF64748B),
    Color(0xFF2563EB),
    Color(0xFFB45309),
    Color(0xFFBE185D),
    Color(0xFF0F766E),
  ];

  static Color forMemberIndex(int index) => members[index % members.length];
}
