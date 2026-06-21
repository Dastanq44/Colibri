import '../../core/result/result.dart';

/// Boundary for persisted reader/fast-mode settings (theme, font, mode lock,
/// speed lock, default WPM, reduced motion, locale, ...). Backed by local
/// Drift tables; implemented in Phase 2 and surfaced in Phase 10.
abstract interface class SettingsRepository {
  // TODO(phase2/10): return typed ReaderSettings + FastSettings models.
  Future<Result<void>> loadReaderSettings();

  Future<Result<void>> saveReaderSettings();
}
