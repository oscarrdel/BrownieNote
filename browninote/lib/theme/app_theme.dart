import 'package:flutter/material.dart';

class AppTheme {
  // ─── Light Colors ─────────────────────────────────────────────────────────
  static const _lightBg = Color(0xFFF5F4FF);
  static const _lightSurface = Color(0xFFFFFFFF);
  static const _lightSurfaceVar = Color(0xFFEEECFF);
  static const _lightPrimary = Color(0xFF5C4EE5);
  static const _lightSecondary = Color(0xFF9B8BFF);
  static const _lightOnPrimary = Color(0xFFFFFFFF);
  static const _lightText = Color(0xFF1A1730);
  static const _lightSubtext = Color(0xFF6E6893);
  static const _lightDivider = Color(0xFFE0DDF5);

  // ─── Dark Colors ──────────────────────────────────────────────────────────
  static const _darkBg = Color(0xFF0F0E1A);
  static const _darkSurface = Color(0xFF1A1830);
  static const _darkSurfaceVar = Color(0xFF242240);
  static const _darkPrimary = Color(0xFF7B6FFF);
  static const _darkSecondary = Color(0xFFB3A9FF);
  static const _darkOnPrimary = Color(0xFF0F0E1A);
  static const _darkText = Color(0xFFECE9FF);
  static const _darkSubtext = Color(0xFF9B96C4);
  static const _darkDivider = Color(0xFF2D2B4E);

  // ─── Subject Colors (palette for notebooks) ───────────────────────────────
  static const List<Color> subjectColors = [
    Color(0xFF5C4EE5), // indigo
    Color(0xFFE5524E), // red-coral
    Color(0xFF4EE5B0), // mint-green
    Color(0xFFE5A84E), // amber
    Color(0xFF4E9EE5), // sky-blue
    Color(0xFFD74EE5), // violet
    Color(0xFF4EE55C), // lime-green
    Color(0xFFE5D44E), // yellow
    Color(0xFFE5734E), // orange
    Color(0xFF4ED4E5), // teal
  ];

  static const List<String> subjectEmojis = [
    '📚', '🔬', '🧮', '🎨', '🌍', '💻', '⚗️', '📖', '🎵', '🏋️',
    '✏️', '🧠', '🌱', '🏛️', '🎭',
  ];

  // ─── Light Theme ──────────────────────────────────────────────────────────
  static ThemeData get light {
    final base = ThemeData(
      brightness: Brightness.light,
      useMaterial3: true,
      colorScheme: const ColorScheme.light(
        primary: _lightPrimary,
        secondary: _lightSecondary,
        surface: _lightSurface,
        onPrimary: _lightOnPrimary,
        onSurface: _lightText,
      ),
    );
    return base.copyWith(
      scaffoldBackgroundColor: _lightBg,
      textTheme: base.textTheme.apply(
        fontFamily: 'Outfit',
        bodyColor: _lightText,
        displayColor: _lightText,
      ),
      extensions: [
        BrownieColors(
          bg: _lightBg,
          surface: _lightSurface,
          surfaceVariant: _lightSurfaceVar,
          primary: _lightPrimary,
          secondary: _lightSecondary,
          text: _lightText,
          subtext: _lightSubtext,
          divider: _lightDivider,
        )
      ],
    );
  }

  // ─── Dark Theme ───────────────────────────────────────────────────────────
  static ThemeData get dark {
    final base = ThemeData(
      brightness: Brightness.dark,
      useMaterial3: true,
      colorScheme: const ColorScheme.dark(
        primary: _darkPrimary,
        secondary: _darkSecondary,
        surface: _darkSurface,
        onPrimary: _darkOnPrimary,
        onSurface: _darkText,
      ),
    );
    return base.copyWith(
      scaffoldBackgroundColor: _darkBg,
      textTheme: base.textTheme.apply(
        fontFamily: 'Outfit',
        bodyColor: _darkText,
        displayColor: _darkText,
      ),
      extensions: [
        BrownieColors(
          bg: _darkBg,
          surface: _darkSurface,
          surfaceVariant: _darkSurfaceVar,
          primary: _darkPrimary,
          secondary: _darkSecondary,
          text: _darkText,
          subtext: _darkSubtext,
          divider: _darkDivider,
        )
      ],
    );
  }
}

/// Custom theme extension for BrownieNote-specific tokens
class BrownieColors extends ThemeExtension<BrownieColors> {
  final Color bg;
  final Color surface;
  final Color surfaceVariant;
  final Color primary;
  final Color secondary;
  final Color text;
  final Color subtext;
  final Color divider;

  const BrownieColors({
    required this.bg,
    required this.surface,
    required this.surfaceVariant,
    required this.primary,
    required this.secondary,
    required this.text,
    required this.subtext,
    required this.divider,
  });

  @override
  BrownieColors copyWith({
    Color? bg,
    Color? surface,
    Color? surfaceVariant,
    Color? primary,
    Color? secondary,
    Color? text,
    Color? subtext,
    Color? divider,
  }) =>
      BrownieColors(
        bg: bg ?? this.bg,
        surface: surface ?? this.surface,
        surfaceVariant: surfaceVariant ?? this.surfaceVariant,
        primary: primary ?? this.primary,
        secondary: secondary ?? this.secondary,
        text: text ?? this.text,
        subtext: subtext ?? this.subtext,
        divider: divider ?? this.divider,
      );

  @override
  BrownieColors lerp(BrownieColors? other, double t) {
    if (other == null) return this;
    return BrownieColors(
      bg: Color.lerp(bg, other.bg, t)!,
      surface: Color.lerp(surface, other.surface, t)!,
      surfaceVariant:
          Color.lerp(surfaceVariant, other.surfaceVariant, t)!,
      primary: Color.lerp(primary, other.primary, t)!,
      secondary: Color.lerp(secondary, other.secondary, t)!,
      text: Color.lerp(text, other.text, t)!,
      subtext: Color.lerp(subtext, other.subtext, t)!,
      divider: Color.lerp(divider, other.divider, t)!,
    );
  }

  static BrownieColors of(BuildContext context) =>
      Theme.of(context).extension<BrownieColors>()!;
}
