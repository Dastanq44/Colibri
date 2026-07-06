import 'dart:io';

import 'package:colibri/data/local/app_database.dart';
import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;

/// Minimal database stub that creates old-shaped tables at [schemaVersion] so
/// opening the real [AppDatabase] on the same file exercises onUpgrade against
/// real data. Only the tables the tested migration steps touch are created.
class _LegacyStubDatabase extends GeneratedDatabase {
  _LegacyStubDatabase(super.executor, this.schemaVersion, this.createStatements);

  @override
  final int schemaVersion;

  final List<String> createStatements;

  @override
  Iterable<TableInfo<Table, dynamic>> get allTables =>
      const <TableInfo<Table, dynamic>>[];

  @override
  MigrationStrategy get migration => MigrationStrategy(
        onCreate: (m) async {
          for (final statement in createStatements) {
            await customStatement(statement);
          }
        },
        // Models an old app binary: it knows nothing about newer versions, so
        // a downgrade only re-stamps user_version without touching tables.
        onUpgrade: (m, from, to) async {},
      );
}

/// `local_reader_settings` as it existed at v1/v2 (no `haptics_enabled`).
const String _readerSettingsV2 = '''
  CREATE TABLE local_reader_settings (
    id INTEGER NOT NULL PRIMARY KEY,
    theme TEXT NOT NULL DEFAULT 'light',
    font_family TEXT NOT NULL DEFAULT 'system',
    font_size INTEGER NOT NULL DEFAULT 18,
    line_height REAL NOT NULL DEFAULT 1.5,
    letter_spacing REAL NOT NULL DEFAULT 0.0,
    page_animation TEXT NOT NULL DEFAULT 'slide',
    mode_lock_enabled INTEGER NOT NULL DEFAULT 0,
    speed_lock_enabled INTEGER NOT NULL DEFAULT 0,
    auto_fast_mode_enabled INTEGER NOT NULL DEFAULT 1,
    reduced_motion INTEGER NOT NULL DEFAULT 0,
    locale TEXT NOT NULL DEFAULT 'ru-RU',
    page_turn_direction TEXT NOT NULL DEFAULT 'ltr',
    updated_at TEXT NOT NULL
  )
''';

const String _seedSettingsRow =
    "INSERT INTO local_reader_settings (id, theme, font_size, updated_at) "
    "VALUES (1, 'dark', 26, '2026-01-01T00:00:00.000Z')";

/// `sync_queue` as it existed at v1 (no `user_id`).
const String _syncQueueV1 = '''
  CREATE TABLE sync_queue (
    id TEXT NOT NULL PRIMARY KEY,
    entity_type TEXT NOT NULL,
    entity_id TEXT NOT NULL,
    operation TEXT NOT NULL,
    payload_json TEXT NOT NULL DEFAULT '{}',
    attempt_count INTEGER NOT NULL DEFAULT 0,
    last_attempt_at TEXT,
    next_attempt_at TEXT,
    status TEXT NOT NULL DEFAULT 'pending',
    created_at TEXT NOT NULL
  )
''';

Future<Set<String>> _columnsOf(GeneratedDatabase db, String table) async {
  final rows = await db.customSelect('PRAGMA table_info($table)').get();
  return rows.map((r) => r.read<String>('name')).toSet();
}

void main() {
  late Directory dir;
  late File file;

  setUp(() async {
    dir = await Directory.systemTemp.createTemp('colibri_migration');
    file = File(p.join(dir.path, 'db.sqlite'));
  });

  tearDown(() => dir.delete(recursive: true));

  Future<void> createLegacyDb(int version, List<String> statements) async {
    final old = _LegacyStubDatabase(NativeDatabase(file), version, statements);
    await old.customSelect('SELECT 1').get(); // force open/create
    await old.close();
  }

  test('v2 -> v3 adds haptics_enabled and keeps existing settings', () async {
    await createLegacyDb(2, const [_readerSettingsV2, _seedSettingsRow]);

    // Reopen with the real database: runs onUpgrade(from: 2, to: 3).
    final db = AppDatabase.forTesting(NativeDatabase(file));
    addTearDown(db.close);

    final row = await db.settingsDao.getReaderSettings();
    expect(row.theme, 'dark'); // pre-migration values survive
    expect(row.fontSize, 26);
    expect(row.hapticsEnabled, isTrue); // new column default

    // The migrated column is writable through the DAO.
    await db.settingsDao.updateReaderSettings(
      const LocalReaderSettingsCompanion(hapticsEnabled: Value(false)),
    );
    expect((await db.settingsDao.getReaderSettings()).hapticsEnabled, isFalse);
  });

  test('v1 -> v3 runs both steps (sync_queue.user_id + haptics_enabled)',
      () async {
    await createLegacyDb(
      1,
      const [_readerSettingsV2, _seedSettingsRow, _syncQueueV1],
    );

    final db = AppDatabase.forTesting(NativeDatabase(file));
    addTearDown(db.close);

    expect(await _columnsOf(db, 'sync_queue'), contains('user_id'));
    final row = await db.settingsDao.getReaderSettings();
    expect(row.theme, 'dark');
    expect(row.hapticsEnabled, isTrue);
  });

  test('downgrade/re-upgrade cycle does not crash on duplicate columns',
      () async {
    // 1. Real v3 database.
    final v3 = AppDatabase.forTesting(NativeDatabase(file));
    await v3.settingsDao.getReaderSettings(); // seed
    await v3.close();

    // 2. "Old binary" opens the file: drift re-stamps user_version = 2
    //    without dropping the newer columns.
    final old = _LegacyStubDatabase(NativeDatabase(file), 2, const []);
    await old.customSelect('SELECT 1').get();
    await old.close();

    // 3. Upgrade again: onUpgrade(from: 2) reruns; addColumn must be
    //    idempotent, not a "duplicate column name" crash.
    final db = AppDatabase.forTesting(NativeDatabase(file));
    addTearDown(db.close);
    final row = await db.settingsDao.getReaderSettings();
    expect(row.hapticsEnabled, isTrue);
  });
}
