import 'package:flutter/material.dart';

/// Typography hooks for the app.
///
/// For the foundation we keep the platform default type scale and expose a
/// single [apply] seam where a custom reading font can be wired in later
/// (Phase 10 / accessibility) without touching theme call sites.
abstract final class AppTextStyles {
  const AppTextStyles._();

  /// Returns the [TextTheme] the app should use. Currently a pass-through so
  /// the system font scale is respected; reader-specific typography is applied
  /// inside the reader, not globally.
  static TextTheme apply(TextTheme base) => base;
}
