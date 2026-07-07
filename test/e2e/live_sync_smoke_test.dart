@Tags(['live'])
library;

import 'dart:convert';
import 'dart:io';

import 'package:colibri/core/result/result.dart';
import 'package:colibri/data/local/app_database.dart';
import 'package:colibri/data/repositories/local_notes_repository.dart';
import 'package:colibri/features/reader/domain/reader_locator.dart';
import 'package:colibri/features/reader/domain/reader_locator_types.dart';
import 'package:colibri/features/sync/data/local_sync_queue_repository.dart';
import 'package:colibri/features/sync/data/supabase_sync_repository.dart';
import 'package:colibri/features/sync/data/sync_payloads.dart';
import 'package:colibri/features/sync/domain/sync_operation.dart';
import 'package:colibri/features/sync/domain/sync_result.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Live smoke test for TASK-1104 acceptance ("notes sync when online"):
/// runs only when a real `.env.dev` with Supabase keys exists next to the
/// project (developer machines); skipped everywhere else (CI).
///
/// Uses a dedicated throwaway account (fixed email) so reruns are idempotent.
Map<String, String>? _loadEnv() {
  final file = File('.env.dev');
  if (!file.existsSync()) return null;
  final env = <String, String>{};
  for (final line in file.readAsLinesSync()) {
    final trimmed = line.trim();
    if (trimmed.isEmpty || trimmed.startsWith('#') || !trimmed.contains('=')) {
      continue;
    }
    final i = trimmed.indexOf('=');
    env[trimmed.substring(0, i)] =
        trimmed.substring(i + 1).replaceAll('"', '');
  }
  final url = env['SUPABASE_URL'] ?? '';
  if (url.isEmpty || url.contains('placeholder')) return null;
  return env;
}

const String _testEmail = 'colibri.sync.smoke@example.com';
const String _testPassword = 'colibri-smoke-3f9a2c!';

/// Prefers a confirmed account from `.env.dev` (SMOKE_TEST_EMAIL /
/// SMOKE_TEST_PASSWORD); falls back to a fixed throwaway signup, which only
/// yields a session when the project has email confirmation disabled.
Future<Session?> _signIn(SupabaseClient client, Map<String, String> env) async {
  final email = env['SMOKE_TEST_EMAIL'] ?? _testEmail;
  final password = env['SMOKE_TEST_PASSWORD'] ?? _testPassword;
  try {
    final res = await client.auth
        .signInWithPassword(email: email, password: password);
    return res.session;
  } on AuthException {
    if (env.containsKey('SMOKE_TEST_EMAIL')) rethrow; // bad configured creds
    try {
      final res =
          await client.auth.signUp(email: email, password: password);
      return res.session; // null when email confirmation is required
    } on AuthException {
      return null; // rate-limited or confirmations required
    }
  }
}

void main() {
  final env = _loadEnv();

  test(
    'book + note + bookmark round-trip against the live dev project',
    () async {
      // Implicit flow: PKCE needs persistent storage a bare test lacks.
      final client = SupabaseClient(
        env!['SUPABASE_URL']!,
        env['SUPABASE_ANON_KEY']!,
        authOptions:
            const AuthClientOptions(authFlowType: AuthFlowType.implicit),
      );
      addTearDown(client.dispose);

      final session = await _signIn(client, env);
      if (session == null) {
        markTestSkipped(
          'No signed-in session: either disable email confirmation on the '
          'dev project, or add SMOKE_TEST_EMAIL/SMOKE_TEST_PASSWORD of a '
          'confirmed account to .env.dev.',
        );
        return;
      }
      final userId = session.user.id;

      final db = AppDatabase.forTesting(NativeDatabase.memory());
      addTearDown(db.close);
      final queue = LocalSyncQueueRepository(db, currentUserId: () => userId);

      // A local book (no file upload — metadata only) and its annotations.
      const bookId = '00000000000000000000000000000e2e';
      await db.booksDao.upsertBook(LocalBooksCompanion.insert(
        id: bookId,
        sourceType: 'upload',
        format: 'txt',
        title: 'Live sync smoke book',
        fileLocalPath: '/dev/null',
      ));
      await queue.enqueueBookCreate(bookId);

      final notes = LocalNotesRepository(db: db, syncQueue: queue);
      const locator = ReaderLocator(
        locatorType: ReaderLocatorTypes.textOffset,
        locatorValue: '10',
        percent: 1,
      );
      final note = (await notes.createNote(bookId,
          locator: locator, noteText: 'smoke note')) as Ok;
      final bookmark = (await notes.createBookmark(bookId,
          locator: locator, label: 'smoke bookmark')) as Ok;

      // Push through the real sync pipeline.
      final sync = SupabaseSyncRepository(client: client, db: db);
      addTearDown(sync.dispose);
      final run = await sync.syncNow();
      final result = (run as Ok<SyncRunResult>).value;
      expect(result.failed, 0,
          reason: 'sync reported failures: $result');
      expect(result.succeeded, greaterThanOrEqualTo(3));

      // Verify the rows landed, via authenticated PostgREST.
      final noteUuid = localBookIdToUuid(note.value.id);
      final cloudNote = await client
          .from('notes')
          .select('note_text, deleted_at')
          .eq('id', noteUuid)
          .maybeSingle();
      expect(cloudNote, isNotNull);
      expect(cloudNote!['note_text'], 'smoke note');
      expect(cloudNote['deleted_at'], isNull);

      final cloudBookmark = await client
          .from('bookmarks')
          .select('label')
          .eq('id', localBookIdToUuid(bookmark.value.id))
          .maybeSingle();
      expect(cloudBookmark?['label'], 'smoke bookmark');

      // Soft delete travels as a tombstone.
      await notes.deleteNote(note.value.id);
      final run2 = ((await sync.syncNow()) as Ok<SyncRunResult>).value;
      expect(run2.failed, 0);
      final tombstoned = await client
          .from('notes')
          .select('deleted_at')
          .eq('id', noteUuid)
          .single();
      expect(tombstoned['deleted_at'], isNotNull);

      // Cleanup (RLS lets the owner delete its own rows; best-effort).
      try {
        await client.from('notes').delete().eq('id', noteUuid);
        await client
            .from('bookmarks')
            .delete()
            .eq('id', localBookIdToUuid(bookmark.value.id));
        await client
            .from('user_bookshelf')
            .delete()
            .eq('book_id', localBookIdToUuid(bookId));
      } catch (_) {/* cleanup is best-effort */}
      await client.auth.signOut();
    },
    skip: env == null
        ? 'no .env.dev with live Supabase keys — live smoke skipped'
        : false,
    timeout: const Timeout(Duration(minutes: 2)),
    tags: 'live',
  );

  // Verify the sync-op payload shapes stay wire-compatible even when the
  // live test is skipped.
  test('note enqueue uses update-only upsert ops', () async {
    final db = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(db.close);
    final queue = LocalSyncQueueRepository(db);
    final notes = LocalNotesRepository(db: db, syncQueue: queue);
    await notes.createNote(
      'b1',
      locator: const ReaderLocator(
          locatorType: ReaderLocatorTypes.textOffset,
          locatorValue: '1',
          percent: 0),
      noteText: 'x',
    );
    final item = (await db.select(db.syncQueue).get()).single;
    expect(SyncOperation.fromWire(item.operation), SyncOperation.update);
    expect((jsonDecode(item.payloadJson) as Map)['book_id'], 'b1');
  });
}
