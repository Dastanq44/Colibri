import 'package:colibri/data/local/app_database.dart';
import 'package:colibri/data/local/sync_status.dart';
// Only `Value` is needed here; importing all of drift would clash with
// flutter_test matchers (e.g. isNotNull).
import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late AppDatabase db;

  setUp(() => db = AppDatabase.forTesting(NativeDatabase.memory()));
  tearDown(() => db.close());

  group('BooksDao', () {
    test('inserts and reads back a local book', () async {
      await db.booksDao.upsertBook(
        LocalBooksCompanion.insert(
          id: 'b1',
          sourceType: 'upload',
          format: 'txt',
          title: 'War and Peace',
          fileLocalPath: '/books/b1.txt',
        ),
      );

      final book = await db.booksDao.getById('b1');

      expect(book, isNotNull);
      expect(book!.title, 'War and Peace');
      expect(book.format, 'txt');
      // Newly imported books default to local-only sync state.
      expect(book.syncStatus, SyncStatus.localOnly);
      expect(book.createdAt, isNotEmpty);
    });

    test('upsert updates an existing book', () async {
      await db.booksDao.upsertBook(
        LocalBooksCompanion.insert(
          id: 'b1',
          sourceType: 'upload',
          format: 'txt',
          title: 'Original',
          fileLocalPath: '/books/b1.txt',
        ),
      );
      await db.booksDao.upsertBook(
        LocalBooksCompanion.insert(
          id: 'b1',
          sourceType: 'upload',
          format: 'txt',
          title: 'Renamed',
          fileLocalPath: '/books/b1.txt',
        ),
      );

      final book = await db.booksDao.getById('b1');
      expect(book!.title, 'Renamed');
      expect(await db.booksDao.getAll(), hasLength(1));
    });
  });

  group('BookshelfDao', () {
    test('updates bookshelf status and marks it for sync', () async {
      await db.bookshelfDao.upsertEntry(
        LocalBookshelfCompanion.insert(bookId: 'b1', status: 'want_to_read'),
      );

      await db.bookshelfDao.setStatus('b1', 'reading');

      final entry = await db.bookshelfDao.getByBookId('b1');
      expect(entry!.status, 'reading');
      expect(entry.syncStatus, SyncStatus.pendingUpdate);
    });
  });

  group('ProgressDao', () {
    test('saves and loads reading progress', () async {
      await db.progressDao.saveProgress(
        LocalReadingProgressCompanion.insert(
          bookId: 'b1',
          deviceId: 'dev-1',
          locatorType: const Value('cfi'),
          locatorValue: const Value('/6/2!/4/10'),
          percent: const Value(12.5),
        ),
      );

      final progress = await db.progressDao.getByBookId('b1');
      expect(progress, isNotNull);
      expect(progress!.locatorValue, '/6/2!/4/10');
      expect(progress.percent, 12.5);
      expect(progress.deviceId, 'dev-1');
      expect(progress.revision, 1);
    });

    test('saving again overwrites the single progress row per book', () async {
      await db.progressDao.saveProgress(
        LocalReadingProgressCompanion.insert(
          bookId: 'b1',
          deviceId: 'dev-1',
          percent: const Value(10.0),
        ),
      );
      await db.progressDao.saveProgress(
        LocalReadingProgressCompanion.insert(
          bookId: 'b1',
          deviceId: 'dev-1',
          percent: const Value(42.0),
        ),
      );

      final progress = await db.progressDao.getByBookId('b1');
      expect(progress!.percent, 42.0);
    });
  });

  group('SyncQueueDao', () {
    test('enqueues and claims pending items', () async {
      await db.syncQueueDao.enqueue(
        SyncQueueCompanion.insert(
          id: 'q1',
          entityType: 'reading_progress',
          entityId: 'b1',
          operation: 'update',
        ),
      );

      final claimed =
          await db.syncQueueDao.claimRunnablePending(userId: 'user-1');
      expect(claimed, hasLength(1));
      expect(claimed.first.entityId, 'b1');
      expect(claimed.first.status, 'processing');
      expect(claimed.first.attemptCount, 0);
    });
  });
}
