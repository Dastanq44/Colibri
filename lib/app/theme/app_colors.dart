import 'package:flutter/material.dart';

/// Neutral **Liquid Glass** palette for the app *chrome* (non-reader UI).
///
/// Liquid Glass is monochrome by design — the glass takes its colour from the
/// content behind it, so the base palette is a neutral white / dark-grey scale
/// with a graphite accent rather than a brand hue. Reader surfaces keep their
/// own [ReaderPalette] (see `reader_theme.dart`).
abstract final class AppColors {
  const AppColors._();

  // Neutral accent (graphite) — used for selection/emphasis, not a brand hue.
  static const Color accent = Color(0xFF3A3A3C);
  static const Color accentDark = Color(0xFFE5E5EA);

  // Light scale (Apple system greys).
  static const Color lightBackground = Color(0xFFF2F2F7);
  static const Color lightSurface = Color(0xFFFFFFFF);
  static const Color lightOnSurface = Color(0xFF1C1C1E);
  static const Color lightOutline = Color(0xFFC7C7CC);

  // Dark scale.
  static const Color darkBackground = Color(0xFF000000);
  static const Color darkSurface = Color(0xFF1C1C1E);
  static const Color darkOnSurface = Color(0xFFF2F2F7);
  static const Color darkOutline = Color(0xFF3A3A3C);

  /// Tint used for frosted-glass fills (semi-transparent white / dark).
  static const Color glassLight = Color(0x66FFFFFF);
  static const Color glassDark = Color(0x40FFFFFF);
}
