import 'package:drift/drift.dart';

import '../db_time.dart';
import '../sync_status.dart';

/// The single, latest reading position per book (the highest-risk data in the
/// product). One row per book; updated in place.
@DataClassName('LocalProgress')
class LocalReadingProgress extends Table {
  TextColumn get bookId => text()();
  TextColumn get locatorType => text().withDefault(const Constant(''))();
  TextColumn get locatorValue => text().withDefault(const Constant(''))();
  TextColumn get chapterHref => text().nullable()();
  IntColumn get chapterIndex => integer().nullable()();
  IntColumn get pageNumber => integer().nullable()();
  IntColumn get paragraphIndex => integer().nullable()();
  IntColumn get tokenIndex => integer().nullable()();
  RealColumn get percent => real().withDefault(const Constant(0.0))();
  TextColumn get mode => text().withDefault(const Constant('normal'))();
  IntColumn get wpm => integer().nullable()();
  TextColumn get deviceId => text()();
  IntColumn get revision => integer().withDefault(const Constant(1))();
  TextColumn get updatedAt => text().clientDefault(dbNow)();
  TextColumn get syncStatus => text()
      .withDefault(const Constant('local_only'))
      .map(const SyncStatusConverter())();

  @override
  Set<Column> get primaryKey => {bookId};
}

/// A reading session (for stats/goals). Appended over time.
@DataClassName('LocalSession')
class LocalReadingSessions extends Table {
  TextColumn get id => text()();
  TextColumn get bookId => text()();
  TextColumn get mode => text()(); // 'normal' | 'fast'
  TextColumn get startedAt => text().clientDefault(dbNow)();
  TextColumn get endedAt => text().nullable()();
  IntColumn get durationSeconds => integer().nullable()();
  IntColumn get wordsRead => integer().nullable()();
  IntColumn get avgWpm => integer().nullable()();
  TextColumn get syncStatus => text()
      .withDefault(const Constant('local_only'))
      .map(const SyncStatusConverter())();

  @override
  Set<Column> get primaryKey => {id};
}
