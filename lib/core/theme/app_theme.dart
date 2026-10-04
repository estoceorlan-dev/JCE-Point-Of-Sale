import 'package:flutter/material.dart';

import 'app_colors.dart';
import 'app_radii.dart';
import 'app_typography.dart';

abstract final class AppTheme {
  static final ThemeData light = _build(
    brightness: Brightness.light,
    colorScheme: ColorScheme.fromSeed(
      seedColor: AppColors.brand,
      brightness: Brightness.light,
      primary: AppColors.brand,
      secondary: AppColors.accent,
      surface: Colors.white,
      error: AppColors.danger,
    ),
  );

  static final ThemeData dark = _build(
    brightness: Brightness.dark,
    colorScheme: ColorScheme.fromSeed(
      seedColor: AppColors.brand,
      brightness: Brightness.dark,
      primary: const Color(0xFF60A5FA),
      secondary: const Color(0xFF22D3EE),
      surface: AppColors.darkSurface,
      error: const Color(0xFFF87171),
    ),
  );

  static ThemeData _build({
    required Brightness brightness,
    required ColorScheme colorScheme,
  }) {
    final isDark = brightness == Brightness.dark;

    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      colorScheme: colorScheme,
      fontFamily: AppTypography.fontFamily,
      scaffoldBackgroundColor: isDark ? AppColors.slate900 : AppColors.slate50,
      textTheme: AppTypography.textTheme(brightness),
      appBarTheme: AppBarTheme(
        centerTitle: false,
        elevation: 0,
        backgroundColor: isDark ? AppColors.slate900 : AppColors.slate50,
        foregroundColor: isDark ? Colors.white : AppColors.slate900,
        surfaceTintColor: Colors.transparent,
        titleTextStyle: AppTypography.textTheme(brightness).titleLarge,
      ),
      cardTheme: CardThemeData(
        elevation: 0,
        color: isDark ? AppColors.darkSurface : Colors.white,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadii.md),
          side: BorderSide(
            color: isDark ? AppColors.darkBorder : AppColors.slate200,
          ),
        ),
      ),
      dividerTheme: DividerThemeData(
        color: isDark ? AppColors.darkBorder : AppColors.slate200,
        thickness: 1,
        space: 1,
      ),
      inputDecorationTheme: InputDecorationThemeData(
        filled: true,
        fillColor: isDark ? AppColors.darkPanel : Colors.white,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadii.md),
          borderSide: BorderSide(
            color: isDark ? AppColors.darkBorder : AppColors.slate200,
          ),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadii.md),
          borderSide: BorderSide(
            color: isDark ? AppColors.darkBorder : AppColors.slate200,
          ),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadii.md),
          borderSide: BorderSide(color: colorScheme.primary, width: 1.5),
        ),
      ),
    );
  }
}
