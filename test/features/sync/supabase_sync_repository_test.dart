import 'package:colibri/core/errors/failures.dart';
import 'package:colibri/core/result/result.dart';
import 'package:colibri/data/local/app_database.dart';
import 'package:colibri/features/sync/data/supabase_sync_repository.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

void main() {
  late AppDatabase db;

  setUp(() => db = AppDatabase.forTesting(NativeDatabase.memory()));
  tearDown(() => db.close());

  Future<void> seedItem() => db.syncQueueDao.enqueueOrReplace(
        entityType: 'book',
        entityId: 'b1',
        operation: 'create',
        payloadJson: '{}',
      );

  test('no backend returns BackendUnavailableFailure and leaves the queue',
      () async {
    await seedItem();
    final repo = SupabaseSyncRepository(client: null, db: db);
    addTearDown(repo.dispose);

    final result = await repo.syncNow();

    expect((result as Err).failure, isA<BackendUnavailableFailure>());
    expect((await db.syncQueueDao.getAll()).single.status, 'pending');
  });

  test('signed out returns UnauthorizedFailure and leaves the queue', () async {
    await seedItem();
    final client = SupabaseClient('https://example.supabase.co', 'anon-key');
    addTearDown(() => client.dispose());
    final repo = SupabaseSyncRepository(client: client, db: db);
    addTearDown(repo.dispose);

    final result = await repo.syncNow();

    expect((result as Err).failure, isA<UnauthorizedFailure>());
    expect((await db.syncQueueDao.getAll()).single.status, 'pending');
  });
}
