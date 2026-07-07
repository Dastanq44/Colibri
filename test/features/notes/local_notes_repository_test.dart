import 'dart:convert';

import 'package:colibri/core/result/result.dart';
import 'package:colibri/data/local/app_database.dart';
import 'package:colibri/data/local/sync_status.dart';
import 'package:colibri/data/repositories/local_notes_repository.dart';
import 'package:colibri/features/reader/domain/reader_locator.dart';
import 'package:colibri/features/reader/domain/reader_locator_types.dart';
import 'package:colibri/features/sync/data/local_sync_queue_repository.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late AppDatabase db;
  late LocalNotesRepository repo;

  const locator = ReaderLocator(
    locatorType: ReaderLocatorTypes.textOffset,
    locatorValue: '1500',
    pageNumber: 3,
    percent: 42,
  );

  setUp(() {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    repo = LocalNotesRepository(
      db: db,
      syncQueue: LocalSyncQueueRepository(db, currentUserId: () => 'user-a'),
    );
  });

  tearDown(() => db.close());

  Future<List<SyncQueueItem>> queueItems() => db.select(db.syncQueue).get();

  group('bookmarks', () {
    test('create persists locator, marks pending and enqueues sync', () async {
      final result = await repo.createBookmark(
        'book-1',
        locator: locator,
        label: '  Chapter start  ',
      );

      final bookmark = (result as Ok).value;
      expect(bookmark.label, 'Chapter start'); // trimmed
      expect(bookmark.textOffset, 1500);

      final rows = await db.notesDao.getBookmarksForBook('book-1');
      expect(rows, hasLength(1));
      expect(rows.single.locatorType, ReaderLocatorTypes.textOffset);
      expect(rows.single.locatorValue, '1500');
      expect(rows.single.syncStatus, SyncStatus.pendingUpload);

      final queue = await queueItems();
      expect(queue, hasLength(1));
      expect(queue.single.entityType, 'bookmark');
      expect(queue.single.operation, 'update');
      final payload = jsonDecode(queue.single.payloadJson) as Map;
      expect(payload['book_id'], 'book-1');
      expect(payload['deleted_at'], isNull);
    });

    test('blank label is stored as null', () async {
      final result = await repo.createBookmark(
        'book-1',
        locator: locator,
        label: '   ',
      );
      expect(((result as Ok).value).label, isNull);
    });

    test('watch emits live changes and hides soft-deleted rows', () async {
      final created =
          await repo.createBookmark('book-1', locator: locator) as Ok;
      expect(await repo.watchBookmarks('book-1').first, hasLength(1));

      await repo.deleteBookmark(created.value.id);
      expect(await repo.watchBookmarks('book-1').first, isEmpty);

      // Soft delete: the row survives with a tombstone, and the coalesced
      // queue snapshot now carries deleted_at.
      final row = await db.notesDao.getBookmarkById(created.value.id);
      expect(row, isNotNull);
      expect(row!.deletedAt, isNotNull);
      expect(row.syncStatus, SyncStatus.deleted);

      final queue = await queueItems();
      expect(queue, hasLength(1)); // same (entity, op) row, replaced payload
      final payload = jsonDecode(queue.single.payloadJson) as Map;
      expect(payload['deleted_at'], isNotNull);
    });
  });

  group('notes', () {
    test('create persists text + locator and enqueues sync', () async {
      final result = await repo.createNote(
        'book-1',
        locator: locator,
        noteText: 'Great passage',
      );

      final note = (result as Ok).value;
      expect(note.noteText, 'Great passage');
      expect(note.textOffset, 1500);

      final queue = await queueItems();
      expect(queue.single.entityType, 'note');
      final payload = jsonDecode(queue.single.payloadJson) as Map;
      expect(payload['note_text'], 'Great passage');
      expect(payload['book_id'], 'book-1');
    });

    test('rejects empty note text without touching the queue', () async {
      final result = await repo.createNote(
        'book-1',
        locator: locator,
        noteText: '   ',
      );
      expect(result, isA<Err<dynamic>>());
      expect(await queueItems(), isEmpty);
      expect(await repo.watchNotes('book-1').first, isEmpty);
    });

    test('delete soft-deletes and re-snapshots the queue payload', () async {
      final created = await repo.createNote(
        'book-1',
        locator: locator,
        noteText: 'To delete',
      ) as Ok;

      await repo.deleteNote(created.value.id);
      expect(await repo.watchNotes('book-1').first, isEmpty);

      final queue = await queueItems();
      expect(queue, hasLength(1));
      final payload = jsonDecode(queue.single.payloadJson) as Map;
      expect(payload['deleted_at'], isNotNull);
    });

    test('notes are ordered newest first', () async {
      await repo.createNote('book-1', locator: locator, noteText: 'first');
      await Future<void>.delayed(const Duration(milliseconds: 5));
      await repo.createNote('book-1', locator: locator, noteText: 'second');

      final notes = await repo.watchNotes('book-1').first;
      expect(notes.map((n) => n.noteText), ['second', 'first']);
    });
  });
}
