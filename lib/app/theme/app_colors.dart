import 'package:flutter/material.dart';

/// Warm-paper **Liquid Glass** palette for the app *chrome* (non-reader UI).
///
/// An Apple-style, reading-friendly skin: a warm off-white "paper" scale with
/// a single terracotta accent, plus a warm near-black dark scale. Neutral and
/// minimal, but warmer than a pure grey system look. Reader surfaces keep their
/// own [ReaderPalette] (see `reader_theme.dart`).
abstract final class AppColors {
  const AppColors._();

  // Terracotta accent — the one tint, used for selection/emphasis/progress.
  static const Color accent = Color(0xFFB4703C);
  static const Color accentDark = Color(0xFFE0925C);

  // Light "paper" scale.
  static const Color lightBackground = Color(0xFFEFE7D9); // grouped background
  static const Color lightSurface = Color(0xFFFFFDF9); // cards/sheets
  static const Color lightSurfaceContainer = Color(0xFFEDE6D8); // filled chips
  static const Color lightOnSurface = Color(0xFF2A2620); // warm ink
  static const Color lightOnSurfaceVariant = Color(0xFF8A8071); // secondary
  static const Color lightOutline = Color(0xFFE4DBCB); // hairline
  static const Color lightOutlineVariant = Color(0xFFEDE6D9);

  // Warm dark scale.
  static const Color darkBackground = Color(0xFF16130D);
  static const Color darkSurface = Color(0xFF211D16);
  static const Color darkSurfaceContainer = Color(0xFF2B2619);
  static const Color darkOnSurface = Color(0xFFECE3D2);
  static const Color darkOnSurfaceVariant = Color(0xFF9C9284);
  static const Color darkOutline = Color(0xFF39332A);
  static const Color darkOutlineVariant = Color(0xFF2C2820);

  /// Tint used for frosted-glass fills (semi-transparent warm white / dark).
  static const Color glassLight = Color(0x66FFFDF9);
  static const Color glassDark = Color(0x40FFFDF9);
}
