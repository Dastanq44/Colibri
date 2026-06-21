import 'package:drift/drift.dart';

import '../db_time.dart';
import '../sync_status.dart';

/// Local mirror of an imported/catalog book (offline-first).
@DataClassName('LocalBook')
class LocalBooks extends Table {
  TextColumn get id => text()();
  TextColumn get cloudBookId => text().nullable()();
  TextColumn get sourceType => text()(); // 'catalog' | 'upload'
  TextColumn get format => text()(); // 'epub' | 'txt' | 'pdf'
  TextColumn get title => text()();
  TextColumn get authorDisplay => text().withDefault(const Constant(''))();
  TextColumn get language => text().withDefault(const Constant(''))();
  TextColumn get coverLocalPath => text().nullable()();
  TextColumn get fileLocalPath => text()();
  TextColumn get checksumSha256 => text().withDefault(const Constant(''))();
  BoolColumn get isFastModeSupported =>
      boolean().withDefault(const Constant(false))();
  TextColumn get textReadyStatus =>
      text().withDefault(const Constant('pending'))();
  TextColumn get createdAt => text().clientDefault(dbNow)();
  TextColumn get updatedAt => text().clientDefault(dbNow)();
  TextColumn get lastOpenedAt => text().nullable()();
  // Default 'local_only'; see SyncStatus.localOnly.
  TextColumn get syncStatus => text()
      .withDefault(const Constant('local_only'))
      .map(const SyncStatusConverter())();

  @override
  Set<Column> get primaryKey => {id};
}

/// Per-user shelf entry / reading status for a book.
@DataClassName('LocalShelfEntry')
class LocalBookshelf extends Table {
  TextColumn get bookId => text()();
  // 'reading' | 'finished' | 'abandoned' | 'want_to_read'
  TextColumn get status => text()();
  IntColumn get rating => integer().nullable()();
  TextColumn get startedAt => text().nullable()();
  TextColumn get finishedAt => text().nullable()();
  TextColumn get addedAt => text().clientDefault(dbNow)();
  TextColumn get lastOpenedAt => text().nullable()();
  TextColumn get syncStatus => text()
      .withDefault(const Constant('local_only'))
      .map(const SyncStatusConverter())();

  @override
  Set<Column> get primaryKey => {bookId};
}
