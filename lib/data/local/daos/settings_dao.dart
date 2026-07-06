import 'package:drift/drift.dart';

import '../app_database.dart';
import '../db_time.dart';
import '../local_defaults.dart';
import '../tables/settings_tables.dart';

part 'settings_dao.g.dart';

/// Reader + fast-mode settings. Both are single-row tables (id = [kSettingsRowId]).
///
/// The first read lazily seeds defaults, so callers always get a complete row.
@DriftAccessor(tables: [LocalReaderSettings, LocalFastSettings])
class SettingsDao extends DatabaseAccessor<AppDatabase>
    with _$SettingsDaoMixin {
  SettingsDao(super.db);

  // --- Reader settings ---

  Future<LocalReaderSettingsRow> getReaderSettings() async {
    final existing = await _readerRow();
    if (existing != null) return existing;
    await into(localReaderSettings).insert(_defaultReaderCompanion());
    return (await _readerRow())!;
  }

  Stream<LocalReaderSettingsRow?> watchReaderSettings() =>
      (select(localReaderSettings)..where((r) => r.id.equals(kSettingsRowId)))
          .watchSingleOrNull();

  Future<void> updateReaderSettings(LocalReaderSettingsCompanion changes) async {
    // Ensure the row exists before patching it.
    await getReaderSettings();
    await (update(localReaderSettings)
          ..where((r) => r.id.equals(kSettingsRowId)))
        .write(changes.copyWith(updatedAt: Value(dbNow())));
  }

  // --- Fast-mode settings ---

  Future<LocalFastSettingsRow> getFastSettings() async {
    final existing = await _fastRow();
    if (existing != null) return existing;
    await into(localFastSettings).insert(_defaultFastCompanion());
    return (await _fastRow())!;
  }

  Stream<LocalFastSettingsRow?> watchFastSettings() =>
      (select(localFastSettings)..where((r) => r.id.equals(kSettingsRowId)))
          .watchSingleOrNull();

  Future<void> updateFastSettings(LocalFastSettingsCompanion changes) async {
    await getFastSettings();
    await (update(localFastSettings)..where((r) => r.id.equals(kSettingsRowId)))
        .write(changes.copyWith(updatedAt: Value(dbNow())));
  }

  // --- internals ---

  Future<LocalReaderSettingsRow?> _readerRow() =>
      (select(localReaderSettings)..where((r) => r.id.equals(kSettingsRowId)))
          .getSingleOrNull();

  Future<LocalFastSettingsRow?> _fastRow() =>
      (select(localFastSettings)..where((r) => r.id.equals(kSettingsRowId)))
          .getSingleOrNull();

  LocalReaderSettingsCompanion _defaultReaderCompanion() =>
      LocalReaderSettingsCompanion(
        id: const Value(kSettingsRowId),
        theme: const Value(ReaderDefaults.theme),
        fontFamily: const Value(ReaderDefaults.fontFamily),
        fontSize: const Value(ReaderDefaults.fontSize),
        lineHeight: const Value(ReaderDefaults.lineHeight),
        letterSpacing: const Value(ReaderDefaults.letterSpacing),
        pageAnimation: const Value(ReaderDefaults.pageAnimation),
        hapticsEnabled: const Value(ReaderDefaults.hapticsEnabled),
        modeLockEnabled: const Value(ReaderDefaults.modeLockEnabled),
        speedLockEnabled: const Value(ReaderDefaults.speedLockEnabled),
        autoFastModeEnabled: const Value(ReaderDefaults.autoFastModeEnabled),
        reducedMotion: const Value(ReaderDefaults.reducedMotion),
        locale: const Value(ReaderDefaults.locale),
        pageTurnDirection: const Value(ReaderDefaults.pageTurnDirection),
        updatedAt: Value(dbNow()),
      );

  LocalFastSettingsCompanion _defaultFastCompanion() =>
      LocalFastSettingsCompanion(
        id: const Value(kSettingsRowId),
        defaultWpm: const Value(FastDefaults.defaultWpm),
        minWpm: const Value(FastDefaults.minWpm),
        maxWpm: const Value(FastDefaults.maxWpm),
        wpmStep: const Value(FastDefaults.wpmStep),
        showAdjacentContext: const Value(FastDefaults.showAdjacentContext),
        chunkMode: const Value(FastDefaults.chunkMode),
        updatedAt: Value(dbNow()),
      );
}
