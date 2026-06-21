import 'package:drift/drift.dart';

import '../db_time.dart';

/// Outbox of local changes awaiting sync to Supabase (processed in Phase 12).
@DataClassName('SyncQueueItem')
class SyncQueue extends Table {
  TextColumn get id => text()();
  TextColumn get entityType => text()();
  TextColumn get entityId => text()();
  TextColumn get operation => text()(); // 'create' | 'update' | 'delete' | 'upload_file'
  TextColumn get payloadJson => text().withDefault(const Constant('{}'))();
  IntColumn get attemptCount => integer().withDefault(const Constant(0))();
  TextColumn get lastAttemptAt => text().nullable()();
  TextColumn get nextAttemptAt => text().nullable()();
  TextColumn get status => text().withDefault(const Constant('pending'))();
  TextColumn get createdAt => text().clientDefault(dbNow)();

  @override
  Set<Column> get primaryKey => {id};
}

/// Generic local key/value store. Backs the persistent device id service and
/// any other small local-only flags.
@DataClassName('LocalKeyValueRow')
class LocalKeyValue extends Table {
  TextColumn get key => text()();
  TextColumn get value => text()();
  TextColumn get updatedAt => text().clientDefault(dbNow)();

  @override
  Set<Column> get primaryKey => {key};
}
