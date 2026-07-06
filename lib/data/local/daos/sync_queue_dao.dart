import 'package:drift/drift.dart';

import '../../../core/utils/id_generator.dart';
import '../../../features/sync/domain/sync_queue_status.dart';
import '../app_database.dart';
import '../db_time.dart';
import '../tables/system_tables.dart';

part 'sync_queue_dao.g.dart';

/// Outbox DAO. The sync engine claims runnable pending items atomically;
/// supports coalescing (one pending row per logical entity+operation+user),
/// attempts and `nextAttemptAt` backoff.
@DriftAccessor(tables: [SyncQueue])
class SyncQueueDao extends DatabaseAccessor<AppDatabase>
    with _$SyncQueueDaoMixin {
  SyncQueueDao(super.db);

  Future<void> enqueue(SyncQueueCompanion item) => into(syncQueue).insert(item);

  /// Inserts a pending item, or replaces the payload of an existing pending one
  /// for the same (entityType, entityId, operation, userId) — avoids duplicate
  /// rows from repeated saves (e.g. fast-mode playback).
  ///
  /// Runs in a transaction so two concurrent enqueues cannot both miss the
  /// existing row and insert duplicates. Safe to call from inside an outer
  /// drift transaction (drift supports nested transactions). Only `pending`
  /// rows are coalesced into: a row claimed by an in-flight sync pass is
  /// `processing`, so a newer save lands in a fresh pending row instead of
  /// mutating a payload that was already snapshotted.
  Future<void> enqueueOrReplace({
    required String entityType,
    required String entityId,
    required String operation,
    required String payloadJson,
    String? userId,
  }) {
    return transaction(() async {
      final existing = await (select(syncQueue)
            ..where((q) =>
                q.entityType.equals(entityType) &
                q.entityId.equals(entityId) &
                q.operation.equals(operation) &
                q.userId.equalsNullable(userId) &
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
            userId: Value(userId),
          ),
        );
      }
    });
  }

  /// Atomically claims runnable pending items for [userId]: selects pending
  /// rows whose backoff (`nextAttemptAt`) has elapsed and that belong to
  /// [userId] or to no user yet, flips them to `processing`, and returns them
  /// (oldest first). Select + flip happen in one transaction, so a save
  /// arriving mid-sync inserts a fresh pending row rather than coalescing into
  /// a claimed one (see [enqueueOrReplace]).
  ///
  /// Unstamped (signed-out) rows stay unstamped here: a claim is not a sync.
  /// They are bound to an account only by [markDone] once an upload actually
  /// succeeded, so a failed pass cannot tie device-local anonymous changes to
  /// the wrong account. ISO-8601 UTC strings compare lexicographically in
  /// time order.
  Future<List<SyncQueueItem>> claimRunnablePending({
    required String userId,
    int limit = 25,
  }) {
    return transaction(() async {
      final now = dbNow();
      final rows = await (select(syncQueue)
            ..where((q) =>
                q.status.equals(SyncQueueStatus.pending) &
                (q.userId.isNull() | q.userId.equals(userId)) &
                (q.nextAttemptAt.isNull() |
                    q.nextAttemptAt.isSmallerOrEqualValue(now)))
            ..orderBy([(q) => OrderingTerm(expression: q.createdAt)])
            ..limit(limit))
          .get();
      if (rows.isEmpty) return rows;

      await (update(syncQueue)
            ..where((q) => q.id.isIn(rows.map((r) => r.id))))
          .write(
        SyncQueueCompanion(
          status: const Value(SyncQueueStatus.processing),
          lastAttemptAt: Value(now),
        ),
      );

      return [
        for (final row in rows)
          row.copyWith(
            status: SyncQueueStatus.processing,
            lastAttemptAt: Value(now),
          ),
      ];
    });
  }

  /// Returns every `processing` row to `pending`, recovering items stranded
  /// by a process kill/crash mid-sync. Only safe to call while no sync pass is
  /// running — the caller (sync engine) guarantees at most one in-process pass
  /// at a time, so anything `processing` here is known to be stranded.
  Future<int> requeueProcessing() {
    return (update(syncQueue)
          ..where((q) => q.status.equals(SyncQueueStatus.processing)))
        .write(const SyncQueueCompanion(
      status: Value(SyncQueueStatus.pending),
    ));
  }

  /// Marks an item synced. [userId] stamps previously unstamped (signed-out)
  /// rows with the account whose upload succeeded — device-local anonymous
  /// changes attach to the first account that actually syncs them.
  Future<void> markDone(String id, {String? userId}) async {
    await (update(syncQueue)..where((q) => q.id.equals(id))).write(
      SyncQueueCompanion(
        status: const Value(SyncQueueStatus.done),
        userId: userId == null ? const Value.absent() : Value(userId),
        lastAttemptAt: Value(dbNow()),
      ),
    );
  }

  /// Returns a claimed item to `pending` after a *transient* failure (device
  /// offline, backend unreachable/5xx). Does NOT touch `attemptCount`:
  /// connectivity retries must never consume the permanent-failure budget.
  Future<void> markRetryLater(
    String id, {
    required Duration retryAfter,
  }) async {
    final next = DateTime.now().toUtc().add(retryAfter).toIso8601String();
    await (update(syncQueue)..where((q) => q.id.equals(id))).write(
      SyncQueueCompanion(
        status: const Value(SyncQueueStatus.pending),
        lastAttemptAt: Value(dbNow()),
        nextAttemptAt: Value(next),
      ),
    );
  }

  /// Records a *permanent* failure: increments attempts and schedules a retry.
  /// Items past [SyncQueueStatus.maxAttempts] are parked as permanently
  /// `failed`; otherwise they return to `pending` with a future
  /// `nextAttemptAt`.
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

  /// Number of items still awaiting sync (`pending`/`processing`) that are
  /// relevant to [userId]: rows stamped with that user plus unstamped
  /// (signed-out) rows. Permanently `failed` rows are excluded — they are not
  /// "waiting" and would inflate the badge forever; [requeueFailed] gives
  /// them another chance. A null [userId] counts across all users.
  Future<int> pendingCount({String? userId}) async {
    final count = countAll();
    final row = await (selectOnly(syncQueue)
          ..addColumns([count])
          ..where(_pendingForUser(userId)))
        .getSingle();
    return row.read(count) ?? 0;
  }

  /// Live version of [pendingCount] — emits whenever the queue changes.
  Stream<int> watchPendingCount({String? userId}) {
    final count = countAll();
    return (selectOnly(syncQueue)
          ..addColumns([count])
          ..where(_pendingForUser(userId)))
        .watchSingle()
        .map((row) => row.read(count) ?? 0);
  }

  Expression<bool> _pendingForUser(String? userId) {
    final awaiting = syncQueue.status.isIn(const [
      SyncQueueStatus.pending,
      SyncQueueStatus.processing,
    ]);
    if (userId == null) return awaiting;
    return awaiting &
        (syncQueue.userId.isNull() | syncQueue.userId.equals(userId));
  }

  /// Returns permanently `failed` rows relevant to [userId] (stamped with
  /// that user or unstamped) to `pending` with a fresh attempt budget. Used
  /// by explicit user-initiated sync so "failed" is never a dead end, while
  /// automatic passes keep skipping known-bad items.
  Future<int> requeueFailed({required String userId}) {
    return (update(syncQueue)
          ..where((q) =>
              q.status.equals(SyncQueueStatus.failed) &
              (q.userId.isNull() | q.userId.equals(userId))))
        .write(const SyncQueueCompanion(
      status: Value(SyncQueueStatus.pending),
      attemptCount: Value(0),
      nextAttemptAt: Value(null),
    ));
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
