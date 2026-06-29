import 'package:drift/drift.dart' show Value;

import '../../../../app/theme/reader_theme.dart';
import '../../../../data/local/app_database.dart';
import '../../fast_mode/domain/fast_mode_settings.dart';
import '../domain/reader_settings.dart';

/// Local-first reader/fast settings, backed by Drift's single-row settings
/// tables. UI reads via providers and writes through the setters here.
class ReaderSettingsRepository {
  ReaderSettingsRepository(this._db);

  final AppDatabase _db;

  Stream<ReaderSettings> watchReaderSettings() async* {
    await _db.settingsDao.getReaderSettings(); // seed defaults
    yield* _db.settingsDao.watchReaderSettings().map(
          (row) => row == null ? ReaderSettings.defaults() : _toReader(row),
        );
  }

  /// Fast settings from the fast-settings row only (speed lock lives in the
  /// reader settings and is combined in the provider).
  Stream<FastModeSettings> watchFastSettings() async* {
    await _db.settingsDao.getFastSettings();
    yield* _db.settingsDao.watchFastSettings().map(
          (row) => row == null ? FastModeSettings.defaults() : _toFast(row),
        );
  }

  Future<void> setTheme(ReaderThemeVariant theme) => _db.settingsDao
      .updateReaderSettings(LocalReaderSettingsCompanion(theme: Value(theme.wire)));

  Future<void> setFontSize(int value) => _db.settingsDao
      .updateReaderSettings(LocalReaderSettingsCompanion(fontSize: Value(value)));

  Future<void> setLineHeight(double value) => _db.settingsDao
      .updateReaderSettings(LocalReaderSettingsCompanion(lineHeight: Value(value)));

  Future<void> setLetterSpacing(double value) =>
      _db.settingsDao.updateReaderSettings(
        LocalReaderSettingsCompanion(letterSpacing: Value(value)),
      );

  Future<void> setModeLock(bool value) => _db.settingsDao.updateReaderSettings(
        LocalReaderSettingsCompanion(modeLockEnabled: Value(value)),
      );

  Future<void> setSpeedLock(bool value) => _db.settingsDao.updateReaderSettings(
        LocalReaderSettingsCompanion(speedLockEnabled: Value(value)),
      );

  Future<void> setDefaultWpm(int value) => _db.settingsDao
      .updateFastSettings(LocalFastSettingsCompanion(defaultWpm: Value(value)));

  Future<void> setShowAdjacentContext(bool value) =>
      _db.settingsDao.updateFastSettings(
        LocalFastSettingsCompanion(showAdjacentContext: Value(value)),
      );

  ReaderSettings _toReader(LocalReaderSettingsRow row) => ReaderSettings(
        theme: ReaderThemeVariant.fromWire(row.theme),
        fontSize: row.fontSize,
        lineHeight: row.lineHeight,
        letterSpacing: row.letterSpacing,
        modeLockEnabled: row.modeLockEnabled,
        speedLockEnabled: row.speedLockEnabled,
        reducedMotion: row.reducedMotion,
        pageTurnDirection: row.pageTurnDirection,
      );

  FastModeSettings _toFast(LocalFastSettingsRow row) => FastModeSettings(
        wpm: row.defaultWpm,
        minWpm: row.minWpm,
        maxWpm: row.maxWpm,
        step: row.wpmStep,
        showAdjacentContext: row.showAdjacentContext,
        speedLockEnabled: false,
      );
}
