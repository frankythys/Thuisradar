import 'package:flutter/material.dart';

/// Kleuren uit het ontwerp (Thuisradar · Android schermen).
abstract final class AppColors {
  static const primary = Color(0xFF005445);
  static const primaryContainer = Color(0xFF0E6E5C);
  static const primarySoft = Color(0xFFE1F2EB);
  static const secondary = Color(0xFF633FCD);
  static const alert = Color(0xFFB4370A);

  /// Lichte oranje tint achter lage-batterij-pills en SOS-badges.
  static const alertSoft = Color(0xFFF7E0D4);
  static const ink = Color(0xFF101E1A);
  static const muted = Color(0xFF3E4945);
  static const ground = Color(0xFFEDFDF6);
  static const surfaceLow = Color(0xFFE7F7F0);
  static const border = Color(0xFFBEC9C4);

  /// Alleen voor kaartselectie; bewust geen kiesbare profielkleur.
  static const mapSelection = Color(0xFF3B1468);

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
