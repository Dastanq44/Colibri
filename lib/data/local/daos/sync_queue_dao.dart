import 'package:drift/drift.dart';

import '../app_database.dart';
import '../db_time.dart';
import '../tables/system_tables.dart';

part 'sync_queue_dao.g.dart';

/// Outbox DAO. The sync engine (Phase 12) consumes pending items; for now this
/// just supports enqueue/read so other layers can record changes.
@DriftAccessor(tables: [SyncQueue])
class SyncQueueDao extends DatabaseAccessor<AppDatabase>
    with _$SyncQueueDaoMixin {
  SyncQueueDao(super.db);

  Future<void> enqueue(SyncQueueCompanion item) =>
      into(syncQueue).insert(item);

  Future<List<SyncQueueItem>> getPending() =>
      (select(syncQueue)..where((q) => q.status.equals('pending'))).get();

  Future<List<SyncQueueItem>> getAll() => select(syncQueue).get();

  Future<void> markAttempt(String id, {required String status}) async {
    final current = await (select(syncQueue)..where((q) => q.id.equals(id)))
        .getSingleOrNull();
    await (update(syncQueue)..where((q) => q.id.equals(id))).write(
      SyncQueueCompanion(
        status: Value(status),
        attemptCount: Value((current?.attemptCount ?? 0) + 1),
        lastAttemptAt: Value(dbNow()),
      ),
    );
  }

  Future<int> deleteById(String id) =>
      (delete(syncQueue)..where((q) => q.id.equals(id))).go();
}
