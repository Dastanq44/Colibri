import 'package:colibri/data/local/app_database.dart';
import 'package:colibri/features/sync/domain/sync_queue_status.dart';
// Only `Value` is needed here; importing all of drift would clash with
// flutter_test matchers (e.g. isNotNull).
import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late AppDatabase db;

  setUp(() => db = AppDatabase.forTesting(NativeDatabase.memory()));
  tearDown(() => db.close());

  Future<void> seed({
    String type = 'book',
    String id = 'b1',
    String op = 'create',
    String payload = '{}',
    String? userId,
  }) =>
      db.syncQueueDao.enqueueOrReplace(
        entityType: type,
        entityId: id,
        operation: op,
        payloadJson: payload,
        userId: userId,
      );

  group('enqueueOrReplace', () {
    test('inserts, then coalesces by entity+operation+user', () async {
      await seed(type: 'reading_progress', op: 'update', payload: '{"v":1}');
      await seed(type: 'reading_progress', op: 'update', payload: '{"v":2}');

      final all = await db.syncQueueDao.getAll();
      expect(all, hasLength(1));
      expect(all.single.payloadJson, '{"v":2}');
    });

    test('does not coalesce across different users', () async {
      await seed(payload: '{"v":1}', userId: 'user-a');
      await seed(payload: '{"v":2}', userId: 'user-b');
      await seed(payload: '{"v":3}'); // signed out (null user)

      expect(await db.syncQueueDao.getAll(), hasLength(3));
    });

    test('concurrent enqueues for the same entity produce one row', () async {
      // The select-then-insert runs in a transaction, so parallel calls must
      // not both miss the existing row and insert duplicates.
      await Future.wait(<Future<void>>[
        for (var i = 0; i < 10; i++) seed(payload: '{"v":$i}'),
      ]);

      expect(await db.syncQueueDao.getAll(), hasLength(1));
    });

    test('does not coalesce into a claimed (processing) row', () async {
      await seed(payload: '{"v":1}', userId: 'user-a');
      await db.syncQueueDao.claimRunnablePending(userId: 'user-a');

      // A save arriving mid-sync must land in a fresh pending row so the
      // in-flight item's markDone cannot swallow the newer payload.
      await seed(payload: '{"v":2}', userId: 'user-a');

      final all = await db.syncQueueDao.getAll();
      expect(all, hasLength(2));
      final statuses = all.map((r) => r.status).toSet();
      expect(statuses,
          {SyncQueueStatus.processing, SyncQueueStatus.pending});
      final pendingRow =
          all.singleWhere((r) => r.status == SyncQueueStatus.pending);
      expect(pendingRow.payloadJson, '{"v":2}');
    });
  });

  group('claimRunnablePending', () {
    test('claims pending rows and flips them to processing', () async {
      await seed(userId: 'user-a');

      final claimed =
          await db.syncQueueDao.claimRunnablePending(userId: 'user-a');

      expect(claimed, hasLength(1));
      expect(claimed.single.status, SyncQueueStatus.processing);
      expect((await db.syncQueueDao.getAll()).single.status,
          SyncQueueStatus.processing);
    });

    test('excludes items with a future nextAttemptAt', () async {
      await seed();
      final id = (await db.syncQueueDao.getAll()).single.id;
      await db.syncQueueDao
          .markFailed(id, retryAfter: const Duration(hours: 1));

      expect(
        await db.syncQueueDao.claimRunnablePending(userId: 'user-a'),
        isEmpty,
      );
    });

    test('does not claim rows stamped with another user', () async {
      await seed(userId: 'user-a');

      final claimed =
          await db.syncQueueDao.claimRunnablePending(userId: 'user-b');

      expect(claimed, isEmpty);
      final row = (await db.syncQueueDao.getAll()).single;
      expect(row.status, SyncQueueStatus.pending);
      expect(row.userId, 'user-a');
    });

    test('claiming a null-user row does NOT stamp it', () async {
      // A claim is not a sync: anonymous rows must stay claimable by any
      // account until an upload actually succeeds (markDone stamps them).
      // Otherwise a fully-failed offline pass would bind signed-out data to
      // whichever account happened to be signed in.
      await seed();

      final claimed =
          await db.syncQueueDao.claimRunnablePending(userId: 'user-a');

      expect(claimed.single.userId, isNull);
      expect((await db.syncQueueDao.getAll()).single.userId, isNull);
    });

    test('markDone stamps a previously unstamped row with the uploader',
        () async {
      await seed();
      final claimed =
          await db.syncQueueDao.claimRunnablePending(userId: 'user-a');

      await db.syncQueueDao.markDone(claimed.single.id, userId: 'user-a');

      final row = (await db.syncQueueDao.getAll()).single;
      expect(row.status, SyncQueueStatus.done);
      expect(row.userId, 'user-a');
    });
  });

  group('requeueFailed', () {
    test('resets failed rows for the user (and unstamped) to pending with a '
        'fresh budget', () async {
      await seed(userId: 'user-a');
      await seed(id: 'book-2');
      await seed(id: 'book-3', userId: 'user-b');
      for (final row in await db.syncQueueDao.getAll()) {
        for (var i = 0; i < SyncQueueStatus.maxAttempts; i++) {
          await db.syncQueueDao.markFailed(row.id, retryAfter: Duration.zero);
        }
      }

      final requeued = await db.syncQueueDao.requeueFailed(userId: 'user-a');

      expect(requeued, 2); // user-a's row + the unstamped row
      final rows = await db.syncQueueDao.getAll();
      final byUser = {for (final r in rows) r.userId: r};
      expect(byUser['user-a']!.status, SyncQueueStatus.pending);
      expect(byUser['user-a']!.attemptCount, 0);
      expect(byUser[null]!.status, SyncQueueStatus.pending);
      expect(byUser['user-b']!.status, SyncQueueStatus.failed);
    });
  });

  test('requeueProcessing returns stranded rows to pending', () async {
    await seed(userId: 'user-a');
    await db.syncQueueDao.claimRunnablePending(userId: 'user-a');
    expect((await db.syncQueueDao.getAll()).single.status,
        SyncQueueStatus.processing);

    final requeued = await db.syncQueueDao.requeueProcessing();

    expect(requeued, 1);
    expect((await db.syncQueueDao.getAll()).single.status,
        SyncQueueStatus.pending);
  });

  test('markRetryLater schedules a retry without consuming attempts',
      () async {
    await seed();
    final id = (await db.syncQueueDao.getAll()).single.id;

    await db.syncQueueDao
        .markRetryLater(id, retryAfter: const Duration(minutes: 5));

    final item = (await db.syncQueueDao.getAll()).single;
    expect(item.attemptCount, 0); // transient failures keep the budget
    expect(item.status, SyncQueueStatus.pending);
    expect(item.nextAttemptAt, isNotNull);
    expect(item.lastAttemptAt, isNotNull);
  });

  test('markFailed increments attempts and schedules a retry', () async {
    await seed();
    final id = (await db.syncQueueDao.getAll()).single.id;

    await db.syncQueueDao.markFailed(id, retryAfter: const Duration(minutes: 5));

    final item = (await db.syncQueueDao.getAll()).single;
    expect(item.attemptCount, 1);
    expect(item.nextAttemptAt, isNotNull);
    expect(item.status, SyncQueueStatus.pending); // retriable
  });

  test('markFailed parks the item as failed at maxAttempts', () async {
    await seed();
    final id = (await db.syncQueueDao.getAll()).single.id;

    for (var i = 0; i < SyncQueueStatus.maxAttempts; i++) {
      await db.syncQueueDao.markFailed(id, retryAfter: Duration.zero);
    }

    final item = (await db.syncQueueDao.getAll()).single;
    expect(item.attemptCount, SyncQueueStatus.maxAttempts);
    expect(item.status, SyncQueueStatus.failed);
  });

  group('pendingCount / watchPendingCount', () {
    test('pendingCount ignores done; deleteDoneOlderThan prunes', () async {
      await seed();
      expect(await db.syncQueueDao.pendingCount(), 1);

      final id = (await db.syncQueueDao.getAll()).single.id;
      await db.syncQueueDao.markDone(id);
      expect(await db.syncQueueDao.pendingCount(), 0);

      await db.syncQueueDao.deleteDoneOlderThan(Duration.zero);
      expect(await db.syncQueueDao.getAll(), isEmpty);
    });

    test('deleteDoneOlderThan keeps recent done rows', () async {
      await seed();
      final id = (await db.syncQueueDao.getAll()).single.id;
      await db.syncQueueDao.markDone(id);

      await db.syncQueueDao.deleteDoneOlderThan(const Duration(days: 7));

      expect(await db.syncQueueDao.getAll(), hasLength(1));
    });

    test('scopes counts to the user plus unstamped rows', () async {
      await seed(id: 'b1', userId: 'user-a');
      await seed(id: 'b2', userId: 'user-b');
      await seed(id: 'b3'); // null user

      expect(await db.syncQueueDao.pendingCount(userId: 'user-a'), 2);
      expect(await db.syncQueueDao.pendingCount(userId: 'user-b'), 2);
      expect(await db.syncQueueDao.pendingCount(), 3);
      expect(
        await db.syncQueueDao.watchPendingCount(userId: 'user-a').first,
        2,
      );
    });

    test('watchPendingCount emits as the queue changes', () async {
      final emissions = <int>[];
      final sub = db.syncQueueDao
          .watchPendingCount(userId: 'user-a')
          .listen(emissions.add);
      addTearDown(sub.cancel);

      await seed(userId: 'user-a');
      // Let the drift stream flush before completing the item.
      await Future<void>.delayed(const Duration(milliseconds: 50));
      final id = (await db.syncQueueDao.getAll()).single.id;
      await db.syncQueueDao.markDone(id);
      await Future<void>.delayed(const Duration(milliseconds: 50));

      expect(emissions, contains(1));
      expect(emissions.last, 0);
    });
  });

  test('migration seam: userId survives insert with explicit value', () async {
    await db.syncQueueDao.enqueue(
      SyncQueueCompanion.insert(
        id: 'q1',
        entityType: 'book',
        entityId: 'b1',
        operation: 'create',
        userId: const Value('user-a'),
      ),
    );

    expect((await db.syncQueueDao.getAll()).single.userId, 'user-a');
  });
}
