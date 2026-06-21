/// App-wide product constants taken directly from the project context and
/// task plan. These describe *product rules* (not features) and are safe to
/// define up front; the engines that consume them arrive in later phases.
abstract final class AppConstants {
  const AppConstants._();

  static const String appName = 'Colibri';

  // --- Fast-mode WPM rules (fast-mode engine: Phase 8 / UI: Phase 9) ---
  static const int defaultWpm = 275;
  static const int minWpm = 150;
  static const int maxWpm = 700;
  static const int wpmStep = 25;
  static const List<int> wpmPresets = <int>[200, 275, 350, 425];

  // --- Reader orientation / feedback timing ---
  /// Stability threshold before the reader reacts to an orientation change,
  /// preventing rapid flips from sensor noise (Phase 9).
  static const Duration modeSwitchStabilityThreshold = Duration(milliseconds: 500);

  /// How long transient WPM/speed feedback stays visible (Phase 9).
  static const Duration speedFeedbackDuration = Duration(milliseconds: 650);

  // --- Reader defaults (reader settings: Phase 2 / Phase 10) ---
  static const double readerFontSizeDefault = 18;
  static const double readerLineHeightDefault = 1.5;
}
