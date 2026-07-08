import 'package:flutter/material.dart';

/// Neutral iOS system palette for the app *chrome* (non-reader UI).
///
/// Mirrors Apple's system colors so the app reads as a native iPhone app:
/// grouped grey backgrounds, white cards, system-blue accent, and the standard
/// dark scale. Deliberately neutral — the reading surface stays customizable
/// via its own [ReaderPalette] (see `reader_theme.dart`).
abstract final class AppColors {
  const AppColors._();

  // iOS system blue — the single accent.
  static const Color accent = Color(0xFF007AFF);
  static const Color accentDark = Color(0xFF0A84FF);

  // Light scale (systemGroupedBackground and friends).
  static const Color lightBackground = Color(0xFFF2F2F7);
  static const Color lightSurface = Color(0xFFFFFFFF);
  static const Color lightSurfaceContainer = Color(0xFFE9E9EB); // filled fields
  static const Color lightOnSurface = Color(0xFF1C1C1E); // label
  static const Color lightOnSurfaceVariant = Color(0xFF8E8E93); // systemGray
  static const Color lightOutline = Color(0xFFC6C6C8); // separator
  static const Color lightOutlineVariant = Color(0xFFE5E5EA);

  // Dark scale.
  static const Color darkBackground = Color(0xFF000000);
  static const Color darkSurface = Color(0xFF1C1C1E);
  static const Color darkSurfaceContainer = Color(0xFF2C2C2E);
  static const Color darkOnSurface = Color(0xFFF2F2F7);
  static const Color darkOnSurfaceVariant = Color(0xFF8E8E93);
  static const Color darkOutline = Color(0xFF38383A);
  static const Color darkOutlineVariant = Color(0xFF2C2C2E);

  /// Tint used for frosted-glass fills (semi-transparent white / dark).
  static const Color glassLight = Color(0x66FFFFFF);
  static const Color glassDark = Color(0x40FFFFFF);
}
