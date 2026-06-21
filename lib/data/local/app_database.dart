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
  int get schemaVersion => 1;

  @override
  MigrationStrategy get migration => MigrationStrategy(
        onCreate: (m) async {
          await m.createAll();
        },
        beforeOpen: (details) async {
          await customStatement('PRAGMA foreign_keys = ON');
        },
      );
}
