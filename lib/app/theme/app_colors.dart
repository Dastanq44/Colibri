import 'package:flutter/material.dart';

/// Brand + neutral color tokens for the app *chrome* (non-reader UI).
///
/// The app's [ColorScheme] is derived from [seed]. Reader surfaces use the
/// dedicated [ReaderPalette] (see `reader_theme.dart`) instead, because the
/// reading area has its own light/sepia/dark treatment.
abstract final class AppColors {
  const AppColors._();

  /// Colibri brand seed color.
  static const Color seed = Color(0xFF3D5AFE);

  static const Color lightBackground = Color(0xFFFDFDFB);
  static const Color darkBackground = Color(0xFF121212);
}
