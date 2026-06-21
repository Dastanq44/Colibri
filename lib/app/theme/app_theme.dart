import 'package:flutter/material.dart';

import 'app_colors.dart';
import 'app_text_styles.dart';

/// Centralized app (chrome) themes. Reader surface themes live in
/// `reader_theme.dart`.
abstract final class AppTheme {
  const AppTheme._();

  static ThemeData light() => _build(Brightness.light);

  static ThemeData dark() => _build(Brightness.dark);

  static ThemeData _build(Brightness brightness) {
    final colorScheme = ColorScheme.fromSeed(
      seedColor: AppColors.seed,
      brightness: brightness,
    );
    final base = ThemeData(
      useMaterial3: true,
      brightness: brightness,
      colorScheme: colorScheme,
    );

    return base.copyWith(
      textTheme: AppTextStyles.apply(base.textTheme),
      appBarTheme: const AppBarTheme(centerTitle: false),
      scaffoldBackgroundColor: colorScheme.surface,
    );
  }
}
