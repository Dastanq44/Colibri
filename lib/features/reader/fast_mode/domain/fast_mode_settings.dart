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
  });

  final int wpm;
  final int minWpm;
  final int maxWpm;
  final int step;
  final bool showAdjacentContext;
  final bool speedLockEnabled;

  factory FastModeSettings.defaults() => const FastModeSettings(
        wpm: AppConstants.defaultWpm,
        minWpm: AppConstants.minWpm,
        maxWpm: AppConstants.maxWpm,
        step: AppConstants.wpmStep,
        showAdjacentContext: true,
        speedLockEnabled: false,
      );

  FastModeSettings copyWith({
    int? wpm,
    bool? showAdjacentContext,
    bool? speedLockEnabled,
  }) {
    return FastModeSettings(
      wpm: wpm ?? this.wpm,
      minWpm: minWpm,
      maxWpm: maxWpm,
      step: step,
      showAdjacentContext: showAdjacentContext ?? this.showAdjacentContext,
      speedLockEnabled: speedLockEnabled ?? this.speedLockEnabled,
    );
  }
}
