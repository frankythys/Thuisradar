import 'package:flutter/material.dart';

import 'app_colors.dart';
import 'app_tokens.dart';

abstract final class AppTheme {
  static const _fontFamily = 'Plus Jakarta Sans';

  static ThemeData light() {
    const tokens = AppTokens.light;
    final scheme = _lightScheme();
    final textTheme = _textTheme(AppColors.ink);

    return ThemeData(
      useMaterial3: true,
      fontFamily: _fontFamily,
      colorScheme: scheme,
      textTheme: textTheme,
      scaffoldBackgroundColor: AppColors.ground,
      extensions: const [tokens],
      appBarTheme: AppBarTheme(
        backgroundColor: AppColors.ground,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        foregroundColor: AppColors.ink,
        titleTextStyle: textTheme.titleLarge,
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: Colors.white,
        hintStyle: textTheme.bodyLarge?.copyWith(color: AppColors.muted),
        contentPadding: EdgeInsets.symmetric(horizontal: tokens.spaceMd, vertical: tokens.spaceMd),
        border: _inputBorder(tokens.radiusInput, const BorderSide(color: Colors.transparent)),
        enabledBorder: _inputBorder(tokens.radiusInput, const BorderSide(color: Colors.transparent)),
        focusedBorder: _inputBorder(tokens.radiusInput, const BorderSide(color: AppColors.primary, width: 2)),
        errorBorder: _inputBorder(tokens.radiusInput, const BorderSide(color: AppColors.alert, width: 1.5)),
        focusedErrorBorder: _inputBorder(
          tokens.radiusInput,
          const BorderSide(color: AppColors.alert, width: 2),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          minimumSize: const Size.fromHeight(52),
          backgroundColor: AppColors.primary,
          foregroundColor: Colors.white,
          textStyle: textTheme.labelLarge,
          shape: const StadiumBorder(),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          minimumSize: const Size.fromHeight(52),
          foregroundColor: AppColors.primary,
          textStyle: textTheme.labelLarge,
          side: const BorderSide(color: AppColors.border),
          shape: const StadiumBorder(),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(foregroundColor: AppColors.primary, textStyle: textTheme.labelLarge),
      ),
      dividerTheme: const DividerThemeData(color: AppColors.border, thickness: 1),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: AppColors.ink,
        contentTextStyle: textTheme.bodyMedium?.copyWith(color: Colors.white),
      ),
    );
  }

  static ColorScheme _lightScheme() {
    return const ColorScheme(
      brightness: Brightness.light,
      primary: AppColors.primary,
      onPrimary: Colors.white,
      primaryContainer: AppColors.primarySoft,
      onPrimaryContainer: AppColors.primary,
      secondary: AppColors.secondary,
      onSecondary: Colors.white,
      secondaryContainer: Color(0xFFE7DEFF),
      onSecondaryContainer: Color(0xFF24115E),
      error: AppColors.alert,
      onError: Colors.white,
      errorContainer: AppColors.alertSoft,
      onErrorContainer: Color(0xFF5A1B00),
      surface: Colors.white,
      onSurface: AppColors.ink,
      onSurfaceVariant: AppColors.muted,
      surfaceContainerLowest: Colors.white,
      surfaceContainerLow: AppColors.ground,
      surfaceContainer: AppColors.ground,
      surfaceContainerHigh: AppColors.primarySoft,
      surfaceContainerHighest: AppColors.primarySoft,
      outline: AppColors.muted,
      outlineVariant: AppColors.border,
    );
  }

  static OutlineInputBorder _inputBorder(double radius, BorderSide side) {
    return OutlineInputBorder(borderRadius: BorderRadius.circular(radius), borderSide: side);
  }

  /// Typografie uit DESIGN.md (Serene Hearth). letterSpacing in px = em × fontSize.
  static TextTheme _textTheme(Color ink) {
    TextStyle style(double size, FontWeight weight, double height, double emTracking) {
      return TextStyle(
        fontFamily: _fontFamily,
        color: ink,
        fontSize: size,
        fontWeight: weight,
        height: height / size,
        letterSpacing: emTracking * size,
      );
    }

    const w800 = FontWeight.w800;
    const w700 = FontWeight.w700;
    const w600 = FontWeight.w600;
    const w500 = FontWeight.w500;
    const w400 = FontWeight.w400;

    return TextTheme(
      displayLarge: style(44, w800, 52, -0.03),
      headlineLarge: style(32, w800, 40, -0.02),
      headlineMedium: style(22, w800, 28, -0.015),
      titleLarge: style(18, w700, 24, -0.01),
      titleMedium: style(16, w600, 22, 0),
      bodyLarge: style(16, w500, 24, 0.01),
      bodyMedium: style(14, w400, 20, 0.01),
      bodySmall: style(12, w400, 16, 0.02),
      labelLarge: style(14, w600, 20, 0.02),
      labelMedium: style(12, w600, 16, 0.03),
      labelSmall: style(11, w700, 14, 0.04),
    );
  }
}
