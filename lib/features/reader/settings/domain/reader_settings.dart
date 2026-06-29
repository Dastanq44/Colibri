import '../../../../app/theme/reader_theme.dart';
import '../../../../data/local/local_defaults.dart';

/// Typed, persisted normal-reader settings (mirrors `local_reader_settings`).
class ReaderSettings {
  const ReaderSettings({
    required this.theme,
    required this.fontSize,
    required this.lineHeight,
    required this.letterSpacing,
    required this.modeLockEnabled,
    required this.speedLockEnabled,
    required this.reducedMotion,
    required this.pageTurnDirection,
  });

  final ReaderThemeVariant theme;
  final int fontSize;
  final double lineHeight;
  final double letterSpacing;
  final bool modeLockEnabled;
  final bool speedLockEnabled;
  final bool reducedMotion;
  final String pageTurnDirection;

  factory ReaderSettings.defaults() => const ReaderSettings(
        theme: ReaderThemeVariant.light,
        fontSize: ReaderDefaults.fontSize,
        lineHeight: ReaderDefaults.lineHeight,
        letterSpacing: ReaderDefaults.letterSpacing,
        modeLockEnabled: ReaderDefaults.modeLockEnabled,
        speedLockEnabled: ReaderDefaults.speedLockEnabled,
        reducedMotion: ReaderDefaults.reducedMotion,
        pageTurnDirection: ReaderDefaults.pageTurnDirection,
      );

  // Sensible UI bounds for the settings controls.
  static const int minFontSize = 12;
  static const int maxFontSize = 32;
  static const double minLineHeight = 1.0;
  static const double maxLineHeight = 2.2;
  static const double minLetterSpacing = -0.5;
  static const double maxLetterSpacing = 2.0;
}
