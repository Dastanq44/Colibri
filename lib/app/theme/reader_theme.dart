import 'package:flutter/material.dart';

/// The three reading surface themes required by the product.
///
/// These are intentionally separate from the app-chrome [ThemeData]: the
/// reading area has its own background/text treatment for comfort, while the
/// surrounding navigation follows the normal light/dark app theme.
enum ReaderThemeVariant { light, sepia, dark }

/// Color palette for a reading surface.
class ReaderPalette {
  const ReaderPalette({
    required this.variant,
    required this.background,
    required this.text,
    required this.dim,
    required this.accent,
  });

  /// Which variant this palette represents.
  final ReaderThemeVariant variant;

  /// Page background behind the text.
  final Color background;

  /// Primary reading text color.
  final Color text;

  /// Dimmed text — used for adjacent (previous/next) context in fast mode.
  final Color dim;

  /// Accent used for the current word / progress highlights.
  final Color accent;

  static const ReaderPalette light = ReaderPalette(
    variant: ReaderThemeVariant.light,
    background: Color(0xFFFFFFFF),
    text: Color(0xFF1A1A1A),
    dim: Color(0xFF9E9E9E),
    accent: Color(0xFF3D5AFE),
  );

  static const ReaderPalette sepia = ReaderPalette(
    variant: ReaderThemeVariant.sepia,
    background: Color(0xFFFBF0D9),
    text: Color(0xFF5B4636),
    dim: Color(0xFFB59E84),
    accent: Color(0xFFB5651D),
  );

  static const ReaderPalette dark = ReaderPalette(
    variant: ReaderThemeVariant.dark,
    background: Color(0xFF121212),
    text: Color(0xFFE6E6E6),
    dim: Color(0xFF6B6B6B),
    accent: Color(0xFF8C9EFF),
  );

  static ReaderPalette of(ReaderThemeVariant variant) {
    return switch (variant) {
      ReaderThemeVariant.light => light,
      ReaderThemeVariant.sepia => sepia,
      ReaderThemeVariant.dark => dark,
    };
  }
}
