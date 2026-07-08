import 'package:flutter/material.dart';

import 'app_colors.dart';
import 'app_text_styles.dart';

/// Centralized app (chrome) themes — a neutral **Liquid Glass** look: a
/// white / dark-grey monochrome scale, translucent app bars, and soft rounded
/// surfaces that let the glass chrome (see `GlassBottomBar`, `GlassSurface`)
/// read against the content behind it. Reader surface themes live in
/// `reader_theme.dart`.
abstract final class AppTheme {
  const AppTheme._();

  static ThemeData light() => _build(Brightness.light);

  static ThemeData dark() => _build(Brightness.dark);

  static ThemeData _build(Brightness brightness) {
    final isDark = brightness == Brightness.dark;

    final colorScheme = ColorScheme(
      brightness: brightness,
      primary: isDark ? AppColors.accentDark : AppColors.accent,
      onPrimary: isDark ? AppColors.darkSurface : Colors.white,
      secondary: isDark ? AppColors.accentDark : AppColors.accent,
      onSecondary: isDark ? AppColors.darkSurface : Colors.white,
      surface: isDark ? AppColors.darkSurface : AppColors.lightSurface,
      onSurface: isDark ? AppColors.darkOnSurface : AppColors.lightOnSurface,
      surfaceContainerHighest:
          isDark ? const Color(0xFF2C2C2E) : const Color(0xFFE9E9EE),
      outline: isDark ? AppColors.darkOutline : AppColors.lightOutline,
      outlineVariant:
          isDark ? const Color(0xFF2C2C2E) : const Color(0xFFD8D8DE),
      error: const Color(0xFFFF453A),
      onError: Colors.white,
    );

    final base = ThemeData(
      useMaterial3: true,
      brightness: brightness,
      colorScheme: colorScheme,
    );

    final scaffoldBg =
        isDark ? AppColors.darkBackground : AppColors.lightBackground;

    return base.copyWith(
      textTheme: AppTextStyles.apply(base.textTheme),
      scaffoldBackgroundColor: scaffoldBg,
      // Translucent, blurred app bars (frosted glass) that float over content.
      appBarTheme: AppBarTheme(
        centerTitle: false,
        elevation: 0,
        scrolledUnderElevation: 0,
        backgroundColor: (isDark ? AppColors.darkBackground : Colors.white)
            .withValues(alpha: 0.7),
        surfaceTintColor: Colors.transparent,
        foregroundColor: colorScheme.onSurface,
      ),
      cardTheme: CardThemeData(
        elevation: 0,
        color: colorScheme.surface.withValues(alpha: isDark ? 0.55 : 0.7),
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(22),
          side: BorderSide(color: colorScheme.outline.withValues(alpha: 0.4)),
        ),
      ),
      // Rounded, soft-glass bottom sheets.
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor:
            colorScheme.surface.withValues(alpha: isDark ? 0.8 : 0.9),
        surfaceTintColor: Colors.transparent,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        ),
        showDragHandle: true,
      ),
      dialogTheme: DialogThemeData(
        backgroundColor:
            colorScheme.surface.withValues(alpha: isDark ? 0.9 : 0.95),
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          side: BorderSide(color: colorScheme.outline.withValues(alpha: 0.6)),
        ),
      ),
      listTileTheme: const ListTileThemeData(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(14)),
        ),
      ),
    );
  }
}
