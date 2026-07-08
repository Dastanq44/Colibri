import 'package:drift/drift.dart';

import 'connection/connection.dart';
import 'daos/books_dao.dart';
import 'daos/bookshelf_dao.dart';
import 'daos/key_value_dao.dart';
import 'daos/notes_dao.dart';
import 'daos/progress_dao.dart';
import 'daos/sessions_dao.dart';
import 'daos/settings_dao.dart';
import 'daos/sync_queue_dao.dart';
// Imported directly (not just transitively via the table files) so the symbols
// the generated part references — SyncStatus(Converter) and dbNow — are in the
// database library's scope.
import 'db_time.dart';
import 'sync_status.dart';
import 'tables/annotation_tables.dart';
import 'tables/book_tables.dart';
import 'tables/reading_tables.dart';
import 'tables/settings_tables.dart';
import 'tables/system_tables.dart';

part 'app_database.g.dart';

/// The app's local-first SQLite database (Drift).
///
/// Owns all local tables and exposes DAOs as the data-access boundary.
/// Repositories use the DAOs; UI never touches DAOs directly.
@DriftDatabase(
  tables: [
    LocalBooks,
    LocalBookshelf,
    LocalReadingProgress,
    LocalReadingSessions,
    LocalBookmarks,
    LocalNotes,
    LocalReaderSettings,
    LocalFastSettings,
    SyncQueue,
    LocalKeyValue,
  ],
  daos: [
    BooksDao,
    BookshelfDao,
    ProgressDao,
    SettingsDao,
    SessionsDao,
    NotesDao,
    SyncQueueDao,
    KeyValueDao,
  ],
)
class AppDatabase extends _$AppDatabase {
  /// Opens the on-device database (default app usage).
  AppDatabase() : super(openConnection());

  /// Test/seam constructor — pass e.g. `NativeDatabase.memory()`.
  AppDatabase.forTesting(super.executor);

  @override
  int get schemaVersion => 5;

  @override
  MigrationStrategy get migration => MigrationStrategy(
        onCreate: (m) async {
          await m.createAll();
        },
        onUpgrade: (m, from, to) async {
          if (from < 2) {
            // v2: sync-queue rows are stamped with the owning user so one
            // account can never upload another account's queued changes.
            await _addColumnIfAbsent(m, syncQueue, syncQueue.userId);
          }
          if (from < 3) {
            // v3: opt-out haptics preference for reader feedback (TASK-1007).
            await _addColumnIfAbsent(
              m,
              localReaderSettings,
              localReaderSettings.hapticsEnabled,
            );
          }
          if (from < 4) {
            // v4: fast-mode natural pauses (hold clause/sentence ends longer).
            await _addColumnIfAbsent(
              m,
              localFastSettings,
              localFastSettings.naturalPausesEnabled,
            );
          }
          if (from < 5) {
            // v5: favourite books flag on the shelf entry.
            await _addColumnIfAbsent(
              m,
              localBookshelf,
              localBookshelf.isFavorite,
            );
          }
        },
        beforeOpen: (details) async {
          await customStatement('PRAGMA foreign_keys = ON');
        },
      );

  /// Idempotent [Migrator.addColumn]: an app downgrade re-stamps a lower
  /// `user_version` without dropping columns, so the next upgrade would
  /// otherwise crash on "duplicate column name" and brick the database.
  Future<void> _addColumnIfAbsent(
    Migrator m,
    TableInfo<Table, dynamic> table,
    GeneratedColumn<Object> column,
  ) async {
    final info = await customSelect(
      'PRAGMA table_info(${table.actualTableName})',
    ).get();
    final exists = info.any((row) => row.read<String>('name') == column.name);
    if (!exists) await m.addColumn(table, column);
  }
}
