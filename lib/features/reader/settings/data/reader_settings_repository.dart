import 'package:drift/drift.dart' show Value;

import '../../../../app/theme/reader_fonts.dart';
import '../../../../app/theme/reader_theme.dart';
import '../../../../data/local/app_database.dart';
import '../../fast_mode/domain/fast_mode_settings.dart';
import '../domain/reader_settings.dart';
import '../domain/reading_profile.dart';

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

  // `page_animation` wire values: anything but 'none' means animated.
  static const String _pageAnimationOn = 'slide';
  static const String _pageAnimationOff = 'none';

  Future<void> setTheme(ReaderThemeVariant theme) => _db.settingsDao
      .updateReaderSettings(LocalReaderSettingsCompanion(theme: Value(theme.wire)));

  Future<void> setFontFamily(ReaderFontFamily value) =>
      _db.settingsDao.updateReaderSettings(
        LocalReaderSettingsCompanion(fontFamily: Value(value.wire)),
      );

  Future<void> setFontSize(int value) => _db.settingsDao
      .updateReaderSettings(LocalReaderSettingsCompanion(fontSize: Value(value)));

  Future<void> setLineHeight(double value) => _db.settingsDao
      .updateReaderSettings(LocalReaderSettingsCompanion(lineHeight: Value(value)));

  Future<void> setLetterSpacing(double value) =>
      _db.settingsDao.updateReaderSettings(
        LocalReaderSettingsCompanion(letterSpacing: Value(value)),
      );

  Future<void> setPageAnimationEnabled(bool value) =>
      _db.settingsDao.updateReaderSettings(
        LocalReaderSettingsCompanion(
          pageAnimation: Value(value ? _pageAnimationOn : _pageAnimationOff),
        ),
      );

  Future<void> setHapticsEnabled(bool value) =>
      _db.settingsDao.updateReaderSettings(
        LocalReaderSettingsCompanion(hapticsEnabled: Value(value)),
      );

  Future<void> setReducedMotion(bool value) =>
      _db.settingsDao.updateReaderSettings(
        LocalReaderSettingsCompanion(reducedMotion: Value(value)),
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

  /// Writes a readability profile's values as plain settings (TASK-1003).
  /// One-tap preset, not a persistent mode — every value stays individually
  /// editable afterwards.
  Future<void> applyProfile(ReadingProfile profile) {
    final preset = ReadingProfilePreset.of(profile);
    final theme = preset.theme;
    return _db.settingsDao.updateReaderSettings(
      LocalReaderSettingsCompanion(
        fontFamily: Value(preset.fontFamily.wire),
        fontSize: Value(preset.fontSize),
        lineHeight: Value(preset.lineHeight),
        letterSpacing: Value(preset.letterSpacing),
        theme: theme == null ? const Value.absent() : Value(theme.wire),
      ),
    );
  }

  ReaderSettings _toReader(LocalReaderSettingsRow row) => ReaderSettings(
        theme: ReaderThemeVariant.fromWire(row.theme),
        fontFamily: ReaderFontFamily.fromWire(row.fontFamily),
        fontSize: row.fontSize,
        lineHeight: row.lineHeight,
        letterSpacing: row.letterSpacing,
        pageAnimationEnabled: row.pageAnimation != _pageAnimationOff,
        hapticsEnabled: row.hapticsEnabled,
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
