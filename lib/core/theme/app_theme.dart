/// SmartDiet AI - Application Theme (Claymorphism)
///
/// Health-centered green Claymorphism theme.
library;

import 'package:flutter/material.dart';
import 'package:smart_diet_ai/core/theme/clay_theme.dart';

class AppTheme {
  AppTheme._();

  // Brand colors (kept for backward compat references)
  static const Color primaryColor = ClayColors.primary;
  static const Color secondaryColor = ClayColors.primaryLight;
  static const Color accentColor = ClayColors.accent;

  // ── Light Theme ───────────────────────────────────────────────────────

  static ThemeData lightTheme = ThemeData(
    useMaterial3: true,
    brightness: Brightness.light,
    colorScheme: ColorScheme(
      brightness: Brightness.light,
      primary: ClayColors.primary,
      onPrimary: Colors.white,
      primaryContainer: ClayColors.primaryMint,
      onPrimaryContainer: ClayColors.primaryDeep,
      secondary: ClayColors.primaryLight,
      onSecondary: Colors.white,
      secondaryContainer: ClayColors.primaryMint.withValues(alpha: 0.5),
      onSecondaryContainer: ClayColors.primaryDeep,
      tertiary: ClayColors.accent,
      onTertiary: Colors.white,
      tertiaryContainer: ClayColors.accent.withValues(alpha: 0.2),
      onTertiaryContainer: const Color(0xFF5C3D00),
      error: ClayColors.error,
      onError: Colors.white,
      errorContainer: ClayColors.error.withValues(alpha: 0.15),
      onErrorContainer: const Color(0xFF8C1D18),
      surface: ClayColors.surface,
      onSurface: const Color(0xFF2D3A2C),
      onSurfaceVariant: const Color(0xFF4A5A49),
      surfaceContainerHighest: ClayColors.surfaceDim,
      outline: ClayColors.shadowDark,
      outlineVariant: ClayColors.shadowDark.withValues(alpha: 0.4),
      shadow: ClayColors.shadowDark,
    ),
    scaffoldBackgroundColor: ClayColors.background,
    appBarTheme: AppBarTheme(
      centerTitle: true,
      elevation: 0,
      backgroundColor: ClayColors.background,
      surfaceTintColor: Colors.transparent,
      foregroundColor: ClayColors.primaryDeep,
      titleTextStyle: const TextStyle(
        color: ClayColors.primaryDeep,
        fontSize: 20,
        fontWeight: FontWeight.w700,
        letterSpacing: -0.3,
      ),
    ),
    cardTheme: CardThemeData(
      elevation: 0,
      color: ClayColors.surfaceCard,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(24),
      ),
      margin: const EdgeInsets.symmetric(vertical: 6),
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: ClayColors.primary,
        foregroundColor: Colors.white,
        elevation: 0,
        padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 16),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
        textStyle: const TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.3,
        ),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: ClayColors.primary,
        side: const BorderSide(color: ClayColors.primaryLight, width: 1.5),
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
        textStyle: const TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w600,
        ),
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        foregroundColor: ClayColors.primary,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        textStyle: const TextStyle(
          fontWeight: FontWeight.w600,
        ),
      ),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: ClayColors.surfaceDim,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(20),
        borderSide: BorderSide.none,
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(20),
        borderSide: BorderSide.none,
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(20),
        borderSide: const BorderSide(color: ClayColors.primary, width: 2),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(20),
        borderSide: const BorderSide(color: ClayColors.error, width: 1.5),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(20),
        borderSide: const BorderSide(color: ClayColors.error, width: 2),
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      prefixIconColor: ClayColors.primaryLight,
      suffixIconColor: ClayColors.primaryLight,
      labelStyle: TextStyle(color: ClayColors.primary.withValues(alpha: 0.7)),
      hintStyle: TextStyle(color: ClayColors.primaryLight.withValues(alpha: 0.6)),
    ),
    floatingActionButtonTheme: FloatingActionButtonThemeData(
      backgroundColor: ClayColors.primary,
      foregroundColor: Colors.white,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
      ),
    ),
    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: ClayColors.surfaceCard,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      indicatorColor: ClayColors.primaryMint,
      iconTheme: WidgetStateProperty.resolveWith((states) {
        if (states.contains(WidgetState.selected)) {
          return const IconThemeData(color: ClayColors.primaryDeep);
        }
        return IconThemeData(color: ClayColors.primaryLight.withValues(alpha: 0.7));
      }),
      labelTextStyle: WidgetStateProperty.resolveWith((states) {
        if (states.contains(WidgetState.selected)) {
          return const TextStyle(
            color: ClayColors.primaryDeep,
            fontSize: 12,
            fontWeight: FontWeight.w700,
          );
        }
        return TextStyle(
          color: ClayColors.primaryLight.withValues(alpha: 0.7),
          fontSize: 12,
          fontWeight: FontWeight.w500,
        );
      }),
      indicatorShape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      height: 72,
    ),
    chipTheme: ChipThemeData(
      color: WidgetStateProperty.resolveWith<Color?>((states) {
        if (states.contains(WidgetState.selected)) return ClayColors.primary;
        return ClayColors.primaryMint;
      }),
      selectedColor: ClayColors.primary,
      disabledColor: ClayColors.surfaceDim,
      checkmarkColor: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: const BorderSide(color: ClayColors.primaryLight, width: 1.5),
      ),
      side: const BorderSide(color: ClayColors.primaryLight, width: 1.5),
      labelStyle: const TextStyle(
        fontWeight: FontWeight.w600,
        color: ClayColors.primaryDeep,
        fontSize: 14,
      ),
      secondaryLabelStyle: const TextStyle(
        fontWeight: FontWeight.w700,
        color: Colors.white,
        fontSize: 14,
      ),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
    ),
    dividerTheme: DividerThemeData(
      color: ClayColors.shadowDark.withValues(alpha: 0.3),
      thickness: 1,
    ),
    snackBarTheme: SnackBarThemeData(
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
    ),
    dialogTheme: DialogThemeData(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
      backgroundColor: ClayColors.surface,
    ),
    popupMenuTheme: PopupMenuThemeData(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      color: ClayColors.surface,
      surfaceTintColor: Colors.transparent,
    ),
    progressIndicatorTheme: const ProgressIndicatorThemeData(
      color: ClayColors.primary,
      linearTrackColor: ClayColors.surfaceDim,
    ),
    textTheme: const TextTheme(
      headlineLarge: TextStyle(fontWeight: FontWeight.w800, letterSpacing: -0.5),
      headlineMedium: TextStyle(fontWeight: FontWeight.w700, letterSpacing: -0.3),
      headlineSmall: TextStyle(fontWeight: FontWeight.w700, letterSpacing: -0.2),
      titleLarge: TextStyle(fontWeight: FontWeight.w700),
      titleMedium: TextStyle(fontWeight: FontWeight.w600),
      titleSmall: TextStyle(fontWeight: FontWeight.w600),
      bodyLarge: TextStyle(fontWeight: FontWeight.w400),
      bodyMedium: TextStyle(fontWeight: FontWeight.w400),
      bodySmall: TextStyle(fontWeight: FontWeight.w400),
      labelLarge: TextStyle(fontWeight: FontWeight.w700),
    ),
  );

  // ── Dark Theme ────────────────────────────────────────────────────────

  static ThemeData darkTheme = ThemeData(
    useMaterial3: true,
    brightness: Brightness.dark,
    colorScheme: ColorScheme(
      brightness: Brightness.dark,
      primary: ClayColors.primaryLight,
      onPrimary: ClayColors.primaryDeep,
      primaryContainer: ClayColors.primaryDeep,
      onPrimaryContainer: ClayColors.primaryMint,
      secondary: ClayColors.primaryMint,
      onSecondary: ClayColors.primaryDeep,
      secondaryContainer: ClayColors.primary.withValues(alpha: 0.3),
      onSecondaryContainer: ClayColors.primaryMint,
      tertiary: ClayColors.accent,
      onTertiary: Colors.white,
      tertiaryContainer: ClayColors.accent.withValues(alpha: 0.2),
      onTertiaryContainer: ClayColors.accent,
      error: const Color(0xFFFFB4AB),
      onError: const Color(0xFF690005),
      errorContainer: ClayColors.error.withValues(alpha: 0.2),
      onErrorContainer: const Color(0xFFFFB4AB),
      surface: ClayColors.darkSurface,
      onSurface: const Color(0xFFD5E5D4),
      onSurfaceVariant: const Color(0xFFA8BCA7),
      surfaceContainerHighest: ClayColors.darkSurfaceCard,
      outline: ClayColors.darkShadowLight,
      outlineVariant: ClayColors.darkShadowLight.withValues(alpha: 0.4),
      shadow: ClayColors.darkShadowDark,
    ),
    scaffoldBackgroundColor: ClayColors.darkBackground,
    appBarTheme: AppBarTheme(
      centerTitle: true,
      elevation: 0,
      backgroundColor: ClayColors.darkBackground,
      surfaceTintColor: Colors.transparent,
      foregroundColor: ClayColors.primaryMint,
      titleTextStyle: const TextStyle(
        color: ClayColors.primaryMint,
        fontSize: 20,
        fontWeight: FontWeight.w700,
        letterSpacing: -0.3,
      ),
    ),
    cardTheme: CardThemeData(
      elevation: 0,
      color: ClayColors.darkSurfaceCard,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(24),
      ),
      margin: const EdgeInsets.symmetric(vertical: 6),
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: ClayColors.primary,
        foregroundColor: Colors.white,
        elevation: 0,
        padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 16),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
        textStyle: const TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.3,
        ),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: ClayColors.primaryLight,
        side: BorderSide(color: ClayColors.primaryLight.withValues(alpha: 0.5), width: 1.5),
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
        textStyle: const TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w600,
        ),
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        foregroundColor: ClayColors.primaryLight,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        textStyle: const TextStyle(
          fontWeight: FontWeight.w600,
        ),
      ),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: ClayColors.darkSurface,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(20),
        borderSide: BorderSide.none,
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(20),
        borderSide: BorderSide.none,
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(20),
        borderSide: const BorderSide(color: ClayColors.primaryLight, width: 2),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(20),
        borderSide: BorderSide(color: ClayColors.error.withValues(alpha: 0.7), width: 1.5),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(20),
        borderSide: const BorderSide(color: ClayColors.error, width: 2),
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      prefixIconColor: ClayColors.primaryMint.withValues(alpha: 0.7),
      suffixIconColor: ClayColors.primaryMint.withValues(alpha: 0.7),
      labelStyle: TextStyle(color: ClayColors.primaryMint.withValues(alpha: 0.7)),
      hintStyle: TextStyle(color: ClayColors.primaryMint.withValues(alpha: 0.4)),
    ),
    floatingActionButtonTheme: FloatingActionButtonThemeData(
      backgroundColor: ClayColors.primary,
      foregroundColor: Colors.white,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
      ),
    ),
    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: ClayColors.darkSurfaceCard,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      indicatorColor: ClayColors.primaryDeep,
      iconTheme: WidgetStateProperty.resolveWith((states) {
        if (states.contains(WidgetState.selected)) {
          return const IconThemeData(color: ClayColors.primaryMint);
        }
        return IconThemeData(color: ClayColors.primaryMint.withValues(alpha: 0.5));
      }),
      labelTextStyle: WidgetStateProperty.resolveWith((states) {
        if (states.contains(WidgetState.selected)) {
          return const TextStyle(
            color: ClayColors.primaryMint,
            fontSize: 12,
            fontWeight: FontWeight.w700,
          );
        }
        return TextStyle(
          color: ClayColors.primaryMint.withValues(alpha: 0.5),
          fontSize: 12,
          fontWeight: FontWeight.w500,
        );
      }),
      indicatorShape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      height: 72,
    ),
    chipTheme: ChipThemeData(
      color: WidgetStateProperty.resolveWith<Color?>((states) {
        if (states.contains(WidgetState.selected)) return ClayColors.primary;
        return ClayColors.primaryDeep.withValues(alpha: 0.25);
      }),
      selectedColor: ClayColors.primary,
      disabledColor: ClayColors.darkSurface,
      checkmarkColor: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: ClayColors.primaryLight.withValues(alpha: 0.5), width: 1.5),
      ),
      side: BorderSide(color: ClayColors.primaryLight.withValues(alpha: 0.5), width: 1.5),
      labelStyle: const TextStyle(
        fontWeight: FontWeight.w600,
        color: ClayColors.primaryMint,
        fontSize: 14,
      ),
      secondaryLabelStyle: const TextStyle(
        fontWeight: FontWeight.w700,
        color: Colors.white,
        fontSize: 14,
      ),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
    ),
    dividerTheme: DividerThemeData(
      color: ClayColors.darkShadowLight.withValues(alpha: 0.3),
      thickness: 1,
    ),
    snackBarTheme: SnackBarThemeData(
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
    ),
    dialogTheme: DialogThemeData(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
      backgroundColor: ClayColors.darkSurface,
    ),
    popupMenuTheme: PopupMenuThemeData(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      color: ClayColors.darkSurface,
      surfaceTintColor: Colors.transparent,
    ),
    progressIndicatorTheme: ProgressIndicatorThemeData(
      color: ClayColors.primaryLight,
      linearTrackColor: ClayColors.darkSurface,
    ),
    textTheme: const TextTheme(
      headlineLarge: TextStyle(fontWeight: FontWeight.w800, letterSpacing: -0.5),
      headlineMedium: TextStyle(fontWeight: FontWeight.w700, letterSpacing: -0.3),
      headlineSmall: TextStyle(fontWeight: FontWeight.w700, letterSpacing: -0.2),
      titleLarge: TextStyle(fontWeight: FontWeight.w700),
      titleMedium: TextStyle(fontWeight: FontWeight.w600),
      titleSmall: TextStyle(fontWeight: FontWeight.w600),
      bodyLarge: TextStyle(fontWeight: FontWeight.w400),
      bodyMedium: TextStyle(fontWeight: FontWeight.w400),
      bodySmall: TextStyle(fontWeight: FontWeight.w400),
      labelLarge: TextStyle(fontWeight: FontWeight.w700),
    ),
  );
}
