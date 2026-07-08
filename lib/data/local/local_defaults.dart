import '../../core/constants/app_constants.dart';

/// Primitive default values for the single-row settings tables.
///
/// Kept as plain constants (no Drift types) so they can be referenced from
/// DAOs and tests without coupling to generated code. WPM values reuse
/// [AppConstants] so the product rules stay defined in one place.

/// The fixed primary-key id used by the single-row settings tables.
const int kSettingsRowId = 1;

abstract final class ReaderDefaults {
  const ReaderDefaults._();

  static const String theme = 'light';
  static const String fontFamily = 'system';
  static const int fontSize = 18;
  static const double lineHeight = 1.5;
  static const double letterSpacing = 0;
  static const String pageAnimation = 'slide';
  static const bool hapticsEnabled = true;
  static const bool modeLockEnabled = false;
  static const bool speedLockEnabled = false;
  static const bool autoFastModeEnabled = true;
  static const bool reducedMotion = false;
  static const String locale = 'ru-RU';
  static const String pageTurnDirection = 'ltr';
}

abstract final class FastDefaults {
  const FastDefaults._();

  static const int defaultWpm = AppConstants.defaultWpm; // 275
  static const int minWpm = AppConstants.minWpm; // 150
  static const int maxWpm = AppConstants.maxWpm; // 700
  static const int wpmStep = AppConstants.wpmStep; // 25
  static const bool showAdjacentContext = true;
  static const bool naturalPausesEnabled = true;
  static const String chunkMode = 'word';
}
