import 'package:drift/drift.dart';

import '../db_time.dart';
import '../sync_status.dart';

/// A bookmark at a locator. Soft-deleted via [deletedAt].
@DataClassName('LocalBookmark')
class LocalBookmarks extends Table {
  TextColumn get id => text()();
  TextColumn get bookId => text()();
  TextColumn get locatorType => text()();
  TextColumn get locatorValue => text()();
  IntColumn get chapterIndex => integer().nullable()();
  IntColumn get paragraphIndex => integer().nullable()();
  IntColumn get tokenIndex => integer().nullable()();
  TextColumn get label => text().nullable()();
  TextColumn get createdAt => text().clientDefault(dbNow)();
  TextColumn get deletedAt => text().nullable()();
  TextColumn get syncStatus => text()
      .withDefault(const Constant('local_only'))
      .map(const SyncStatusConverter())();

  @override
  Set<Column> get primaryKey => {id};
}

/// A note/highlight at a locator. Soft-deleted via [deletedAt].
@DataClassName('LocalNote')
class LocalNotes extends Table {
  TextColumn get id => text()();
  TextColumn get bookId => text()();
  TextColumn get locatorType => text()();
  TextColumn get locatorValue => text()();
  TextColumn get selectedText => text().nullable()();
  TextColumn get noteText => text()();
  TextColumn get color => text().nullable()();
  TextColumn get createdAt => text().clientDefault(dbNow)();
  TextColumn get updatedAt => text().clientDefault(dbNow)();
  TextColumn get deletedAt => text().nullable()();
  TextColumn get syncStatus => text()
      .withDefault(const Constant('local_only'))
      .map(const SyncStatusConverter())();

  @override
  Set<Column> get primaryKey => {id};
}
