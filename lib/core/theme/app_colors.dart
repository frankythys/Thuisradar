import 'package:flutter/material.dart';

/// Kleuren uit het ontwerp (Thuisradar · Android schermen).
abstract final class AppColors {
  static const primary = Color(0xFF0E6E5C);
  static const primarySoft = Color(0xFFDCEFE9);
  static const alert = Color(0xFFB4370A);
  static const ink = Color(0xFF12201C);
  static const muted = Color(0xFF5B6763);
  static const ground = Color(0xFFF3F5F4);
  static const border = Color(0xFFE2E7E5);

  /// Vaste kleur per gezinslid, op volgorde van toetreden.
  static const members = [
    Color(0xFF0E6E5C),
    Color(0xFF6D4BD8),
    Color(0xFF2563EB),
    Color(0xFFB45309),
    Color(0xFFBE185D),
    Color(0xFF0F766E),
  ];

  static Color forMemberIndex(int index) => members[index % members.length];
}
