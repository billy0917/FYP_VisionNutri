/// SmartDiet AI - Claymorphism Design System
///
/// Reusable clay-style decorations and color palette for the entire app.
library;

import 'package:flutter/material.dart';

// ── Health-Centered Green Palette ──────────────────────────────────────────

class ClayColors {
  ClayColors._();

  // Primary greens
  static const Color primary = Color(0xFF5B8C5A);
  static const Color primaryLight = Color(0xFF8FBC8B);
  static const Color primaryMint = Color(0xFFB8D8BA);
  static const Color primaryDeep = Color(0xFF3A6B35);

  // Surfaces
  static const Color background = Color(0xFFF0F5EE);
  static const Color surface = Color(0xFFF7FAF6);
  static const Color surfaceDim = Color(0xFFE6EDE4);
  static const Color surfaceCard = Color(0xFFEFF5ED);

  // Dark mode surfaces
  static const Color darkBackground = Color(0xFF1A2419);
  static const Color darkSurface = Color(0xFF243323);
  static const Color darkSurfaceCard = Color(0xFF2C3E2B);

  // Accents
  static const Color accent = Color(0xFFE8B059);
  static const Color accentCoral = Color(0xFFE88B6A);

  // Shadows (for clay effect)
  static const Color shadowDark = Color(0xFFB5C8B4);
  static const Color shadowLight = Color(0xFFFFFFFF);
  static const Color darkShadowDark = Color(0xFF0D160D);
  static const Color darkShadowLight = Color(0xFF3A4D39);

  // Nutrient colors (softer for clay)
  static const Color calorie = Color(0xFFE8A84C);
  static const Color protein = Color(0xFF6B9BD2);
  static const Color carbs = Color(0xFF7BC47F);
  static const Color fat = Color(0xFFD68B6B);

  // Status
  static const Color error = Color(0xFFD26B6B);
  static const Color success = Color(0xFF5B8C5A);
}

// ── Claymorphism Decoration Builders ─────────────────────────────────────

class ClayDecoration {
  ClayDecoration._();

  /// Standard clay card decoration — the signature puffy raised look.
  static BoxDecoration card({
    Color? color,
    double radius = 24,
    bool isDark = false,
  }) {
    final bg = color ?? (isDark ? ClayColors.darkSurfaceCard : ClayColors.surfaceCard);
    return BoxDecoration(
      color: bg,
      borderRadius: BorderRadius.circular(radius),
      boxShadow: [
        // Outer bottom-right shadow (darker)
        BoxShadow(
          color: isDark ? ClayColors.darkShadowDark : ClayColors.shadowDark,
          offset: const Offset(6, 6),
          blurRadius: 16,
          spreadRadius: 1,
        ),
        // Outer top-left highlight (lighter)
        BoxShadow(
          color: isDark ? ClayColors.darkShadowLight : ClayColors.shadowLight,
          offset: const Offset(-4, -4),
          blurRadius: 12,
          spreadRadius: 1,
        ),
      ],
    );
  }

  /// Pressed / concave clay decoration (for inputs, inset fields).
  static BoxDecoration pressed({
    Color? color,
    double radius = 20,
    bool isDark = false,
  }) {
    final bg = color ?? (isDark ? ClayColors.darkSurface : ClayColors.surfaceDim);
    return BoxDecoration(
      color: bg,
      borderRadius: BorderRadius.circular(radius),
      boxShadow: [
        // Inner shadow (simulated with inset-like look)
        BoxShadow(
          color: isDark
              ? ClayColors.darkShadowDark.withValues(alpha: 0.6)
              : ClayColors.shadowDark.withValues(alpha: 0.5),
          offset: const Offset(3, 3),
          blurRadius: 8,
          spreadRadius: -2,
        ),
        BoxShadow(
          color: isDark
              ? ClayColors.darkShadowLight.withValues(alpha: 0.3)
              : ClayColors.shadowLight.withValues(alpha: 0.8),
          offset: const Offset(-2, -2),
          blurRadius: 6,
          spreadRadius: -2,
        ),
      ],
    );
  }

  /// Flat clay surface (for backgrounds, containers with minimal depth).
  static BoxDecoration flat({
    Color? color,
    double radius = 20,
    bool isDark = false,
  }) {
    final bg = color ?? (isDark ? ClayColors.darkSurfaceCard : ClayColors.surfaceCard);
    return BoxDecoration(
      color: bg,
      borderRadius: BorderRadius.circular(radius),
      boxShadow: [
        BoxShadow(
          color: isDark ? ClayColors.darkShadowDark : ClayColors.shadowDark,
          offset: const Offset(3, 3),
          blurRadius: 8,
          spreadRadius: 0,
        ),
        BoxShadow(
          color: isDark ? ClayColors.darkShadowLight : ClayColors.shadowLight,
          offset: const Offset(-2, -2),
          blurRadius: 6,
          spreadRadius: 0,
        ),
      ],
    );
  }

  /// Prominent clay button decoration.
  static BoxDecoration button({
    Color? color,
    double radius = 20,
    bool isDark = false,
  }) {
    final bg = color ?? ClayColors.primary;
    return BoxDecoration(
      color: bg,
      borderRadius: BorderRadius.circular(radius),
      boxShadow: [
        BoxShadow(
          color: bg.withValues(alpha: 0.4),
          offset: const Offset(4, 4),
          blurRadius: 12,
          spreadRadius: 0,
        ),
        BoxShadow(
          color: isDark ? ClayColors.darkShadowLight : ClayColors.shadowLight,
          offset: const Offset(-2, -2),
          blurRadius: 8,
          spreadRadius: 0,
        ),
      ],
    );
  }

  /// Circle avatar clay decoration.
  static BoxDecoration circle({
    Color? color,
    bool isDark = false,
  }) {
    final bg = color ?? (isDark ? ClayColors.darkSurfaceCard : ClayColors.surfaceCard);
    return BoxDecoration(
      color: bg,
      shape: BoxShape.circle,
      boxShadow: [
        BoxShadow(
          color: isDark ? ClayColors.darkShadowDark : ClayColors.shadowDark,
          offset: const Offset(4, 4),
          blurRadius: 10,
          spreadRadius: 0,
        ),
        BoxShadow(
          color: isDark ? ClayColors.darkShadowLight : ClayColors.shadowLight,
          offset: const Offset(-3, -3),
          blurRadius: 8,
          spreadRadius: 0,
        ),
      ],
    );
  }

  /// Small badge / chip clay decoration.
  static BoxDecoration badge({
    required Color color,
    double radius = 14,
  }) {
    return BoxDecoration(
      color: color.withValues(alpha: 0.18),
      borderRadius: BorderRadius.circular(radius),
      boxShadow: [
        BoxShadow(
          color: color.withValues(alpha: 0.12),
          offset: const Offset(2, 2),
          blurRadius: 4,
        ),
      ],
    );
  }
}

// ── Reusable Clay Container Widget ──────────────────────────────────────

class ClayContainer extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry? padding;
  final EdgeInsetsGeometry? margin;
  final double radius;
  final Color? color;
  final bool pressed;
  final double? width;
  final double? height;

  const ClayContainer({
    super.key,
    required this.child,
    this.padding,
    this.margin,
    this.radius = 24,
    this.color,
    this.pressed = false,
    this.width,
    this.height,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final decoration = pressed
        ? ClayDecoration.pressed(color: color, radius: radius, isDark: isDark)
        : ClayDecoration.card(color: color, radius: radius, isDark: isDark);

    return Container(
      width: width,
      height: height,
      padding: padding ?? const EdgeInsets.all(16),
      margin: margin,
      decoration: decoration,
      child: child,
    );
  }
}
