import 'dart:convert';
import 'dart:io';

import 'package:colibri/core/errors/failures.dart';
import 'package:colibri/core/result/result.dart';
import 'package:colibri/data/local/app_database.dart';
import 'package:colibri/features/sync/data/supabase_sync_repository.dart';
import 'package:colibri/features/sync/domain/sync_queue_status.dart';
import 'package:colibri/features/sync/domain/sync_result.dart';
import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// A Supabase client with a locally-seeded session (no network involved):
/// the access token is not a decodable JWT, so no expiry is known and the
/// session is treated as valid.
Future<SupabaseClient> _signedInClient(
  String url, {
  String userId = 'user-a',
}) async {
  final client = SupabaseClient(url, 'anon-key');
  await client.auth.setInitialSession(jsonEncode(<String, dynamic>{
    'access_token': 'header.payload.signature',
    'token_type': 'bearer',
    'user': <String, dynamic>{'id': userId},
  }));
  return client;
}

void main() {
  late AppDatabase db;

  setUp(() => db = AppDatabase.forTesting(NativeDatabase.memory()));
  tearDown(() => db.close());

  Future<void> seedItem({
    String id = 'b1',
    String? userId,
  }) =>
      db.syncQueueDao.enqueueOrReplace(
        entityType: 'book',
        entityId: id,
        operation: 'create',
        payloadJson: '{"format":"txt","title":"T"}',
        userId: userId,
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

  group('signed in', () {
    test(
        'offline failure returns the item to pending unstamped and '
        'does not consume the attempt budget', () async {
      await seedItem(); // enqueued while signed out -> null user
      // Port 1 refuses connections: a pure connectivity (transient) error.
      final client = await _signedInClient('http://127.0.0.1:1');
      addTearDown(() => client.dispose());
      final repo = SupabaseSyncRepository(client: client, db: db);
      addTearDown(repo.dispose);

      final result = await repo.syncNow();

      final run = (result as Ok<SyncRunResult>).value;
      expect(run.processed, 1);
      expect(run.failed, 1);
      final row = (await db.syncQueueDao.getAll()).single;
      expect(row.status, SyncQueueStatus.pending); // not stranded/failed
      expect(row.attemptCount, 0); // offline never consumes attempts
      // Nothing synced, so the anonymous row must NOT be bound to this
      // account — only a successful upload (markDone) stamps it.
      expect(row.userId, isNull);
      expect(row.nextAttemptAt, isNotNull); // backoff still applies
    });

    test('failed items get a fresh budget when retryFailed is set', () async {
      await seedItem(userId: 'user-a');
      final id = (await db.syncQueueDao.getAll()).single.id;
      for (var i = 0; i < SyncQueueStatus.maxAttempts; i++) {
        await db.syncQueueDao.markFailed(id, retryAfter: Duration.zero);
      }
      expect((await db.syncQueueDao.getAll()).single.status,
          SyncQueueStatus.failed);

      final client = await _signedInClient('http://127.0.0.1:1');
      addTearDown(() => client.dispose());
      final repo = SupabaseSyncRepository(client: client, db: db);
      addTearDown(repo.dispose);

      // Without retryFailed the parked item stays invisible to the pass.
      expect(
          ((await repo.syncNow()) as Ok<SyncRunResult>).value.processed, 0);

      // With it, the item is requeued, re-claimed and attempted again.
      final retried = await repo.syncNow(retryFailed: true);
      expect((retried as Ok<SyncRunResult>).value.processed, 1);
      final row = (await db.syncQueueDao.getAll()).single;
      expect(row.status, SyncQueueStatus.pending); // transient failure again
      expect(row.attemptCount, 0); // fresh budget
    });

    test('a 4xx response consumes an attempt (permanent classification)',
        () async {
      final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      addTearDown(() => server.close(force: true));
      server.listen((req) {
        req.response
          ..statusCode = 400
          ..headers.contentType = ContentType.json
          ..write('{"message":"invalid input","code":"22P02"}');
        req.response.close();
      });

      await seedItem(userId: 'user-a');
      final client =
          await _signedInClient('http://127.0.0.1:${server.port}');
      addTearDown(() => client.dispose());
      final repo = SupabaseSyncRepository(client: client, db: db);
      addTearDown(repo.dispose);

      final result = await repo.syncNow();

      final run = (result as Ok<SyncRunResult>).value;
      expect(run.failed, 1);
      final row = (await db.syncQueueDao.getAll()).single;
      expect(row.attemptCount, 1);
      expect(row.status, SyncQueueStatus.pending); // retriable until max
    });

    test('rows stranded in processing by a dead run are requeued and retried',
        () async {
      await seedItem(userId: 'user-a');
      // Simulate a previous sync pass that died mid-flight after claiming.
      await db.syncQueueDao.claimRunnablePending(userId: 'user-a');
      expect((await db.syncQueueDao.getAll()).single.status,
          SyncQueueStatus.processing);

      final client = await _signedInClient('http://127.0.0.1:1');
      addTearDown(() => client.dispose());
      final repo = SupabaseSyncRepository(client: client, db: db);
      addTearDown(repo.dispose);

      final result = await repo.syncNow();

      // The stranded row was requeued, re-claimed and attempted this pass.
      expect((result as Ok<SyncRunResult>).value.processed, 1);
      expect((await db.syncQueueDao.getAll()).single.status,
          SyncQueueStatus.pending);
    });

    test('items stamped with another user are not claimed or uploaded',
        () async {
      await seedItem(userId: 'user-b');
      final client = await _signedInClient('http://127.0.0.1:1');
      addTearDown(() => client.dispose());
      final repo = SupabaseSyncRepository(client: client, db: db);
      addTearDown(repo.dispose);

      final result = await repo.syncNow();

      expect((result as Ok<SyncRunResult>).value.processed, 0);
      final row = (await db.syncQueueDao.getAll()).single;
      expect(row.userId, 'user-b');
      expect(row.status, SyncQueueStatus.pending);
      expect(row.attemptCount, 0);
    });

    test('a sync pass prunes done rows older than a week, keeps recent ones',
        () async {
      final oldCreatedAt = DateTime.now()
          .toUtc()
          .subtract(const Duration(days: 8))
          .toIso8601String();
      await db.syncQueueDao.enqueue(SyncQueueCompanion.insert(
        id: 'old-done',
        entityType: 'book',
        entityId: 'b-old',
        operation: 'create',
        status: const Value(SyncQueueStatus.done),
        createdAt: Value(oldCreatedAt),
      ));
      await db.syncQueueDao.enqueue(SyncQueueCompanion.insert(
        id: 'recent-done',
        entityType: 'book',
        entityId: 'b-recent',
        operation: 'create',
        status: const Value(SyncQueueStatus.done),
      ));

      final client = await _signedInClient('http://127.0.0.1:1');
      addTearDown(() => client.dispose());
      final repo = SupabaseSyncRepository(client: client, db: db);
      addTearDown(repo.dispose);

      final result = await repo.syncNow();

      expect(result, isA<Ok<SyncRunResult>>());
      final remaining = await db.syncQueueDao.getAll();
      expect(remaining, hasLength(1));
      expect(remaining.single.id, 'recent-done');
    });

    test('unexpected internal errors become an Err instead of a throw',
        () async {
      // A database that cannot be opened: every queue call throws.
      final deadDb = AppDatabase.forTesting(
        NativeDatabase(File('/nonexistent-dir/colibri/dead.sqlite')),
      );
      addTearDown(() async {
        try {
          await deadDb.close();
        } catch (_) {/* never opened */}
      });
      final client = await _signedInClient('http://127.0.0.1:1');
      addTearDown(() => client.dispose());
      final repo = SupabaseSyncRepository(client: client, db: deadDb);
      addTearDown(repo.dispose);

      final result = await repo.syncNow();

      expect((result as Err).failure, isA<UnknownFailure>());
    });
  });
}
