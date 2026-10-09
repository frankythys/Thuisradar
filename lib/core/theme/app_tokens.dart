import 'package:flutter/material.dart';

import 'app_colors.dart';

/// Ontwerp-tokens (radii, spacing, schaduwen, gezinslid-kleuren) die widgets
/// via `Theme.of(context).extension<AppTokens>()` lezen. Zo staan er geen
/// hardgecodeerde maten of kleuren in de widgets en kan donkere modus later
/// een tweede variant leveren.
@immutable
class AppTokens extends ThemeExtension<AppTokens> {
  const AppTokens({
    required this.radiusSm,
    required this.radiusMd,
    required this.radiusCard,
    required this.radiusInput,
    required this.radiusSheet,
    required this.spaceXs,
    required this.spaceSm,
    required this.spaceMd,
    required this.spaceLg,
    required this.spaceXl,
    required this.spaceXxl,
    required this.shadowLevel1,
    required this.shadowLevel2,
    required this.shadowSheet,
    required this.shadowMarker,
    required this.glowSelection,
    required this.memberColors,
  });

  final double radiusSm;
  final double radiusMd;
  final double radiusCard;
  final double radiusInput;
  final double radiusSheet;

  final double spaceXs;
  final double spaceSm;
  final double spaceMd;
  final double spaceLg;
  final double spaceXl;
  final double spaceXxl;

  /// Niveau 1: kaarten en statische containers.
  final List<BoxShadow> shadowLevel1;

  /// Niveau 2: zwevende kaartknoppen en modals.
  final List<BoxShadow> shadowLevel2;

  /// Niveau 3: vaste bottom sheets en SOS-overlays.
  final List<BoxShadow> shadowSheet;

  /// Duidelijke slagschaduw onder de cirkels op de kaart.
  final List<BoxShadow> shadowMarker;

  /// Zachte gloed in de selectiekleur rond het gekozen lid op de kaart.
  final List<BoxShadow> glowSelection;

  final List<Color> memberColors;

  Color memberColor(int index) => memberColors[index % memberColors.length];

  static const light = AppTokens(
    radiusSm: 8,
    radiusMd: 12,
    radiusCard: 20,
    radiusInput: 16,
    radiusSheet: 28,
    spaceXs: 4,
    spaceSm: 8,
    spaceMd: 16,
    spaceLg: 20,
    spaceXl: 28,
    spaceXxl: 40,
    shadowLevel1: [
      BoxShadow(color: Color(0x0A12201C), blurRadius: 20, spreadRadius: -2, offset: Offset(0, 4)),
      BoxShadow(color: Color(0x0512201C), blurRadius: 6, spreadRadius: -1, offset: Offset(0, 2)),
    ],
    shadowLevel2: [
      BoxShadow(color: Color(0x1412201C), blurRadius: 30, spreadRadius: -4, offset: Offset(0, 8)),
      BoxShadow(color: Color(0x0812201C), blurRadius: 12, spreadRadius: -2, offset: Offset(0, 4)),
    ],
    shadowSheet: [BoxShadow(color: Color(0x1412201C), blurRadius: 32, offset: Offset(0, -8))],
    shadowMarker: [
      BoxShadow(color: Color(0x4012201C), blurRadius: 12, offset: Offset(0, 5)),
      BoxShadow(color: Color(0x2612201C), blurRadius: 3, offset: Offset(0, 1)),
    ],
    // AppColors.mapSelection (#762EEA) op 45 % en 20 %.
    glowSelection: [
      BoxShadow(color: Color(0x73762EEA), blurRadius: 18, spreadRadius: 2),
      BoxShadow(color: Color(0x33762EEA), blurRadius: 36, spreadRadius: 6),
    ],
    memberColors: AppColors.members,
  );

  @override
  AppTokens copyWith({
    double? radiusSm,
    double? radiusMd,
    double? radiusCard,
    double? radiusInput,
    double? radiusSheet,
    double? spaceXs,
    double? spaceSm,
    double? spaceMd,
    double? spaceLg,
    double? spaceXl,
    double? spaceXxl,
    List<BoxShadow>? shadowLevel1,
    List<BoxShadow>? shadowLevel2,
    List<BoxShadow>? shadowSheet,
    List<BoxShadow>? shadowMarker,
    List<BoxShadow>? glowSelection,
    List<Color>? memberColors,
  }) {
    return AppTokens(
      radiusSm: radiusSm ?? this.radiusSm,
      radiusMd: radiusMd ?? this.radiusMd,
      radiusCard: radiusCard ?? this.radiusCard,
      radiusInput: radiusInput ?? this.radiusInput,
      radiusSheet: radiusSheet ?? this.radiusSheet,
      spaceXs: spaceXs ?? this.spaceXs,
      spaceSm: spaceSm ?? this.spaceSm,
      spaceMd: spaceMd ?? this.spaceMd,
      spaceLg: spaceLg ?? this.spaceLg,
      spaceXl: spaceXl ?? this.spaceXl,
      spaceXxl: spaceXxl ?? this.spaceXxl,
      shadowLevel1: shadowLevel1 ?? this.shadowLevel1,
      shadowLevel2: shadowLevel2 ?? this.shadowLevel2,
      shadowSheet: shadowSheet ?? this.shadowSheet,
      shadowMarker: shadowMarker ?? this.shadowMarker,
      glowSelection: glowSelection ?? this.glowSelection,
      memberColors: memberColors ?? this.memberColors,
    );
  }

  @override
  AppTokens lerp(ThemeExtension<AppTokens>? other, double t) {
    if (other is! AppTokens) return this;
    return AppTokens(
      radiusSm: lerpDouble(radiusSm, other.radiusSm, t),
      radiusMd: lerpDouble(radiusMd, other.radiusMd, t),
      radiusCard: lerpDouble(radiusCard, other.radiusCard, t),
      radiusInput: lerpDouble(radiusInput, other.radiusInput, t),
      radiusSheet: lerpDouble(radiusSheet, other.radiusSheet, t),
      spaceXs: lerpDouble(spaceXs, other.spaceXs, t),
      spaceSm: lerpDouble(spaceSm, other.spaceSm, t),
      spaceMd: lerpDouble(spaceMd, other.spaceMd, t),
      spaceLg: lerpDouble(spaceLg, other.spaceLg, t),
      spaceXl: lerpDouble(spaceXl, other.spaceXl, t),
      spaceXxl: lerpDouble(spaceXxl, other.spaceXxl, t),
      shadowLevel1: BoxShadow.lerpList(shadowLevel1, other.shadowLevel1, t) ?? shadowLevel1,
      shadowLevel2: BoxShadow.lerpList(shadowLevel2, other.shadowLevel2, t) ?? shadowLevel2,
      shadowSheet: BoxShadow.lerpList(shadowSheet, other.shadowSheet, t) ?? shadowSheet,
      shadowMarker: BoxShadow.lerpList(shadowMarker, other.shadowMarker, t) ?? shadowMarker,
      glowSelection: BoxShadow.lerpList(glowSelection, other.glowSelection, t) ?? glowSelection,
      memberColors: t < 0.5 ? memberColors : other.memberColors,
    );
  }

  static double lerpDouble(double a, double b, double t) => a + (b - a) * t;
}

/// Korte toegang tot de tokens vanuit een widget.
extension AppTokensContext on BuildContext {
  AppTokens get tokens => Theme.of(this).extension<AppTokens>()!;
}
