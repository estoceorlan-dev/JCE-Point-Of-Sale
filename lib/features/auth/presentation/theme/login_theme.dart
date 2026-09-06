import 'package:flutter/material.dart';

import '../../../../core/theme/app_radii.dart';

/// Warm brand colors scoped to authentication, derived from the cover artwork.
abstract final class LoginTheme {
  static ThemeData from(ThemeData base) {
    final isDark = base.brightness == Brightness.dark;
    final background = isDark
        ? const Color(0xFF241C17)
        : const Color(0xFFFFE9C9);
    final text = isDark ? const Color(0xFFFFE9C9) : const Color(0xFF39271D);
    final muted = isDark ? const Color(0xFFD3BDA7) : const Color(0xFF745B47);
    final scheme = base.colorScheme.copyWith(
      primary: isDark ? const Color(0xFFE4B28B) : const Color(0xFF784425),
      onPrimary: isDark ? const Color(0xFF39271D) : const Color(0xFFFFF8EF),
      surface: isDark ? const Color(0xFF30251E) : const Color(0xFFFFF6E9),
      onSurface: text,
      onSurfaceVariant: muted,
      outline: isDark ? const Color(0xFF997A61) : const Color(0xFFB69B7E),
      outlineVariant: isDark
          ? const Color(0xFF604A39)
          : const Color(0xFFDAC1A2),
    );
    final border = OutlineInputBorder(
      borderRadius: BorderRadius.circular(AppRadii.md),
      borderSide: BorderSide(color: scheme.outlineVariant),
    );

    return base.copyWith(
      colorScheme: scheme,
      scaffoldBackgroundColor: background,
      textTheme: base.textTheme.apply(bodyColor: text, displayColor: text),
      inputDecorationTheme: base.inputDecorationTheme.copyWith(
        fillColor: scheme.surface,
        hintStyle: base.textTheme.bodyLarge?.copyWith(color: muted),
        suffixIconColor: muted,
        border: border,
        enabledBorder: border,
        focusedBorder: border.copyWith(
          borderSide: BorderSide(color: scheme.primary, width: 1.5),
        ),
      ),
      textSelectionTheme: TextSelectionThemeData(
        cursorColor: scheme.primary,
        selectionColor: scheme.primary.withValues(alpha: 0.24),
        selectionHandleColor: scheme.primary,
      ),
    );
  }
}
