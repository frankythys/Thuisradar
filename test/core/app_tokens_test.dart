import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:thuisradar/core/theme/app_colors.dart';
import 'package:thuisradar/core/theme/app_tokens.dart';

void main() {
  const tokens = AppTokens.light;

  test('memberColor loopt rond bij een index buiten het bereik', () {
    expect(tokens.memberColor(0), AppColors.members[0]);
    expect(tokens.memberColor(AppColors.members.length), AppColors.members[0]);
    expect(tokens.memberColor(AppColors.members.length + 1), AppColors.members[1]);
  });

  test('eerste vier gezinslid-kleuren volgen DESIGN.md', () {
    expect(tokens.memberColor(0), AppColors.primaryContainer);
    expect(tokens.memberColor(1), const Color(0xFF6D4BD8));
    expect(tokens.memberColor(2), const Color(0xFF2563EB));
    expect(tokens.memberColor(3), const Color(0xFFB45309));
  });

  test('lerp naar een niet-AppTokens geeft zichzelf terug', () {
    expect(tokens.lerp(null, 0.5), same(tokens));
  });

  test('lerp mengt maten en kiest kleurenlijst per helft', () {
    final other = tokens.copyWith(radiusCard: 40);
    final mid = tokens.lerp(other, 0.5);
    expect(mid.radiusCard, 30);
    expect(mid.memberColors, other.memberColors);
  });
}
