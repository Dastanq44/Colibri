import 'package:flutter/material.dart';

/// App type scale, tuned to feel like iOS / SF Pro.
///
/// On iOS Flutter already renders with the San Francisco system font; this just
/// reshapes the weights, sizes and letter-spacing to match Apple's hierarchy:
/// heavy, slightly tightened large titles down to a calm 17pt body. Colours are
/// left to the theme so light/dark both work. Reader typography is applied
/// separately inside the reader, not here.
abstract final class AppTextStyles {
  const AppTextStyles._();

  static TextTheme apply(TextTheme base) {
    return base.copyWith(
      // iOS "large title" (34) and its neighbours — heavy, gently tightened.
      displaySmall: _s(base.displaySmall, 34, FontWeight.w700, -0.4),
      headlineMedium: _s(base.headlineMedium, 28, FontWeight.w700, -0.3),
      headlineSmall: _s(base.headlineSmall, 24, FontWeight.w700, -0.2),
      // Section / row titles.
      titleLarge: _s(base.titleLarge, 22, FontWeight.w700, -0.2),
      titleMedium: _s(base.titleMedium, 17, FontWeight.w600, -0.1),
      titleSmall: _s(base.titleSmall, 15, FontWeight.w600, -0.1),
      // Body.
      bodyLarge: _s(base.bodyLarge, 17, FontWeight.w400, -0.1),
      bodyMedium: _s(base.bodyMedium, 15, FontWeight.w400, -0.1),
      bodySmall: _s(base.bodySmall, 13, FontWeight.w400, 0),
      // Labels (buttons, captions).
      labelLarge: _s(base.labelLarge, 16, FontWeight.w600, -0.1),
      labelMedium: _s(base.labelMedium, 13, FontWeight.w600, 0),
      labelSmall: _s(base.labelSmall, 12, FontWeight.w500, 0.1),
    );
  }

  static TextStyle? _s(
    TextStyle? base,
    double size,
    FontWeight weight,
    double tracking,
  ) =>
      base?.copyWith(
        fontSize: size,
        fontWeight: weight,
        letterSpacing: tracking,
        height: 1.25,
      );
}
