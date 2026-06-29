import 'package:colibri/data/local/app_database.dart';
import 'package:colibri/features/sync/domain/sync_queue_status.dart';
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
  }) =>
      db.syncQueueDao.enqueueOrReplace(
        entityType: type,
        entityId: id,
        operation: op,
        payloadJson: payload,
      );

  test('enqueueOrReplace inserts, then coalesces by entity+operation', () async {
    await seed(type: 'reading_progress', op: 'update', payload: '{"v":1}');
    await seed(type: 'reading_progress', op: 'update', payload: '{"v":2}');

    final all = await db.syncQueueDao.getAll();
    expect(all, hasLength(1));
    expect(all.single.payloadJson, '{"v":2}');
  });

  test('getRunnablePending excludes items with a future nextAttemptAt',
      () async {
    await seed();
    expect(await db.syncQueueDao.getRunnablePending(), hasLength(1));

    final id = (await db.syncQueueDao.getAll()).single.id;
    await db.syncQueueDao.markFailed(id, retryAfter: const Duration(hours: 1));

    expect(await db.syncQueueDao.getRunnablePending(), isEmpty);
  });

  test('markProcessing then markDone update status', () async {
    await seed();
    final id = (await db.syncQueueDao.getAll()).single.id;

    await db.syncQueueDao.markProcessing(id);
    expect((await db.syncQueueDao.getAll()).single.status,
        SyncQueueStatus.processing);

    await db.syncQueueDao.markDone(id);
    expect((await db.syncQueueDao.getAll()).single.status, SyncQueueStatus.done);
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

  test('pendingCount ignores done; deleteDoneOlderThan prunes', () async {
    await seed();
    expect(await db.syncQueueDao.pendingCount(), 1);

    final id = (await db.syncQueueDao.getAll()).single.id;
    await db.syncQueueDao.markDone(id);
    expect(await db.syncQueueDao.pendingCount(), 0);

    await db.syncQueueDao.deleteDoneOlderThan(Duration.zero);
    expect(await db.syncQueueDao.getAll(), isEmpty);
  });
}
