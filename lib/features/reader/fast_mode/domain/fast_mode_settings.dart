import '../../../../core/constants/app_constants.dart';

/// Fast-mode tuning. Defaults reuse [AppConstants] so the WPM product rules
/// stay defined in one place.
class FastModeSettings {
  const FastModeSettings({
    required this.wpm,
    required this.minWpm,
    required this.maxWpm,
    required this.step,
    required this.showAdjacentContext,
    required this.speedLockEnabled,
    required this.naturalPausesEnabled,
  });

  final int wpm;
  final int minWpm;
  final int maxWpm;
  final int step;
  final bool showAdjacentContext;
  final bool speedLockEnabled;

  /// When on, words ending a clause/sentence/paragraph linger a little longer
  /// (see NaturalPause). Default on.
  final bool naturalPausesEnabled;

  factory FastModeSettings.defaults() => const FastModeSettings(
        wpm: AppConstants.defaultWpm,
        minWpm: AppConstants.minWpm,
        maxWpm: AppConstants.maxWpm,
        step: AppConstants.wpmStep,
        showAdjacentContext: true,
        speedLockEnabled: false,
        naturalPausesEnabled: true,
      );

  FastModeSettings copyWith({
    int? wpm,
    bool? showAdjacentContext,
    bool? speedLockEnabled,
    bool? naturalPausesEnabled,
  }) {
    return FastModeSettings(
      wpm: wpm ?? this.wpm,
      minWpm: minWpm,
      maxWpm: maxWpm,
      step: step,
      showAdjacentContext: showAdjacentContext ?? this.showAdjacentContext,
      speedLockEnabled: speedLockEnabled ?? this.speedLockEnabled,
      naturalPausesEnabled: naturalPausesEnabled ?? this.naturalPausesEnabled,
    );
  }
}
