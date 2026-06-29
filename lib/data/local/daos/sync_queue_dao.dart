import 'package:drift/drift.dart';

import '../../../core/utils/id_generator.dart';
import '../../../features/sync/domain/sync_queue_status.dart';
import '../app_database.dart';
import '../db_time.dart';
import '../tables/system_tables.dart';

part 'sync_queue_dao.g.dart';

/// Outbox DAO. The sync engine consumes runnable pending items; supports
/// coalescing (one pending row per logical entity+operation), attempts and
/// `nextAttemptAt` backoff.
@DriftAccessor(tables: [SyncQueue])
class SyncQueueDao extends DatabaseAccessor<AppDatabase>
    with _$SyncQueueDaoMixin {
  SyncQueueDao(super.db);

  Future<void> enqueue(SyncQueueCompanion item) => into(syncQueue).insert(item);

  /// Inserts a pending item, or replaces the payload of an existing pending one
  /// for the same (entityType, entityId, operation) — avoids duplicate rows
  /// from repeated saves (e.g. fast-mode playback).
  Future<void> enqueueOrReplace({
    required String entityType,
    required String entityId,
    required String operation,
    required String payloadJson,
  }) async {
    final existing = await (select(syncQueue)
          ..where((q) =>
              q.entityType.equals(entityType) &
              q.entityId.equals(entityId) &
              q.operation.equals(operation) &
              q.status.equals(SyncQueueStatus.pending))
          ..limit(1))
        .getSingleOrNull();

    if (existing != null) {
      await (update(syncQueue)..where((q) => q.id.equals(existing.id))).write(
        SyncQueueCompanion(
          payloadJson: Value(payloadJson),
          nextAttemptAt: const Value(null),
        ),
      );
    } else {
      await into(syncQueue).insert(
        SyncQueueCompanion.insert(
          id: IdGenerator.newId(),
          entityType: entityType,
          entityId: entityId,
          operation: operation,
          payloadJson: Value(payloadJson),
        ),
      );
    }
  }

  /// Pending items whose backoff (`nextAttemptAt`) has elapsed, oldest first.
  /// ISO-8601 UTC strings compare lexicographically in time order.
  Future<List<SyncQueueItem>> getRunnablePending({int limit = 25}) {
    final now = dbNow();
    return (select(syncQueue)
          ..where((q) =>
              q.status.equals(SyncQueueStatus.pending) &
              (q.nextAttemptAt.isNull() |
                  q.nextAttemptAt.isSmallerOrEqualValue(now)))
          ..orderBy([(q) => OrderingTerm(expression: q.createdAt)])
          ..limit(limit))
        .get();
  }

  Future<void> markProcessing(String id) async {
    await (update(syncQueue)..where((q) => q.id.equals(id))).write(
      SyncQueueCompanion(
        status: const Value(SyncQueueStatus.processing),
        lastAttemptAt: Value(dbNow()),
      ),
    );
  }

  Future<void> markDone(String id) async {
    await (update(syncQueue)..where((q) => q.id.equals(id))).write(
      SyncQueueCompanion(
        status: const Value(SyncQueueStatus.done),
        lastAttemptAt: Value(dbNow()),
      ),
    );
  }

  /// Increments attempts and schedules a retry. Items past
  /// [SyncQueueStatus.maxAttempts] are parked as permanently `failed`;
  /// otherwise they return to `pending` with a future `nextAttemptAt`.
  Future<void> markFailed(
    String id, {
    required Duration retryAfter,
  }) async {
    final current =
        await (select(syncQueue)..where((q) => q.id.equals(id))).getSingleOrNull();
    final attempts = (current?.attemptCount ?? 0) + 1;
    final permanent = attempts >= SyncQueueStatus.maxAttempts;
    final next = DateTime.now().toUtc().add(retryAfter).toIso8601String();

    await (update(syncQueue)..where((q) => q.id.equals(id))).write(
      SyncQueueCompanion(
        status: Value(
          permanent ? SyncQueueStatus.failed : SyncQueueStatus.pending,
        ),
        attemptCount: Value(attempts),
        lastAttemptAt: Value(dbNow()),
        nextAttemptAt: Value(next),
      ),
    );
  }

  /// Number of items still needing sync (anything not `done`).
  Future<int> pendingCount() async {
    final count = countAll();
    final row = await (selectOnly(syncQueue)
          ..addColumns([count])
          ..where(syncQueue.status.equals(SyncQueueStatus.done).not()))
        .getSingle();
    return row.read(count) ?? 0;
  }

  Future<void> deleteDoneOlderThan(Duration age) async {
    final cutoff = DateTime.now().toUtc().subtract(age).toIso8601String();
    await (delete(syncQueue)
          ..where((q) =>
              q.status.equals(SyncQueueStatus.done) &
              q.createdAt.isSmallerThanValue(cutoff)))
        .go();
  }

  Future<List<SyncQueueItem>> getAll() => select(syncQueue).get();

  Future<int> deleteForEntity(String entityId) =>
      (delete(syncQueue)..where((q) => q.entityId.equals(entityId))).go();
}
