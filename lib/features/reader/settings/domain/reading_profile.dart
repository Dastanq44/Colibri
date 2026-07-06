import '../../../../app/theme/reader_fonts.dart';
import '../../../../app/theme/reader_theme.dart';
import '../../../../data/local/local_defaults.dart';

/// One-tap readability presets (TASK-1003).
///
/// Applying a profile writes plain settings values — it is not a persistent
/// mode, so the user can customize every value afterwards.
enum ReadingProfile { standard, highReadability, dyslexia, lowVision }

/// The text-setting values a [ReadingProfile] writes when applied.
class ReadingProfilePreset {
  const ReadingProfilePreset({
    required this.fontFamily,
    required this.fontSize,
    required this.lineHeight,
    required this.letterSpacing,
    this.theme,
  });

  final ReaderFontFamily fontFamily;
  final int fontSize;
  final double lineHeight;
  final double letterSpacing;

  /// Suggested theme — only set by profiles that recommend one (low vision
  /// suggests the high-contrast dark surface); null leaves the theme alone.
  final ReaderThemeVariant? theme;

  static ReadingProfilePreset of(ReadingProfile profile) => switch (profile) {
        ReadingProfile.standard => const ReadingProfilePreset(
            fontFamily: ReaderFontFamily.system,
            fontSize: ReaderDefaults.fontSize,
            lineHeight: ReaderDefaults.lineHeight,
            letterSpacing: ReaderDefaults.letterSpacing,
          ),
        ReadingProfile.highReadability => const ReadingProfilePreset(
            fontFamily: ReaderFontFamily.system,
            fontSize: 22,
            lineHeight: 1.8,
            letterSpacing: 0.5,
          ),
        ReadingProfile.dyslexia => const ReadingProfilePreset(
            fontFamily: ReaderFontFamily.system,
            fontSize: 24,
            lineHeight: 2.0,
            letterSpacing: 1.2,
          ),
        ReadingProfile.lowVision => const ReadingProfilePreset(
            fontFamily: ReaderFontFamily.system,
            fontSize: 30,
            lineHeight: 2.0,
            letterSpacing: 0.4,
            theme: ReaderThemeVariant.dark,
          ),
      };
}
