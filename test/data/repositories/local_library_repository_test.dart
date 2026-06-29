import 'dart:io';

import 'package:colibri/core/result/result.dart';
import 'package:colibri/data/local/app_database.dart';
import 'package:colibri/data/repositories/local_library_repository.dart';
import 'package:colibri/features/import/data/file_storage_service.dart';
import 'package:colibri/features/library/domain/library_book.dart';
import 'package:colibri/features/sync/data/local_sync_queue_repository.dart';
import 'package:colibri/shared/models/bookshelf_status.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late AppDatabase db;
  late Directory tmp;
  late LocalLibraryRepository repo;

  setUp(() {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    tmp = Directory.systemTemp.createTempSync('colibri_lib');
    repo = LocalLibraryRepository(
      db,
      FileStorageService(baseDirectory: tmp),
      LocalSyncQueueRepository(db),
    );
  });

  tearDown(() async {
    await db.close();
    if (tmp.existsSync()) tmp.deleteSync(recursive: true);
  });

  Future<void> seedBook(String id, {String status = 'reading'}) async {
    await db.booksDao.upsertBook(
      LocalBooksCompanion.insert(
        id: id,
        sourceType: 'upload',
        format: 'txt',
        title: 'Book $id',
        fileLocalPath: '/tmp/$id.txt',
      ),
    );
    await db.bookshelfDao.upsertEntry(
      LocalBookshelfCompanion.insert(bookId: id, status: status),
    );
  }

  List<LibraryBook> unwrap(Result<List<LibraryBook>> r) => switch (r) {
        Ok(value: final v) => v,
        Err() => <LibraryBook>[],
      };

  test('imported/local book appears in getMyBooks', () async {
    await seedBook('b1');

    final books = unwrap(await repo.getMyBooks());

    expect(books, hasLength(1));
    expect(books.single.title, 'Book b1');
    expect(books.single.status, BookShelfStatus.reading);
    expect(books.single.percent, 0);
  });

  test('updateBookStatus changes the bookshelf status', () async {
    await seedBook('b1');

    await repo.updateBookStatus('b1', BookShelfStatus.finished);

    final books = unwrap(await repo.getMyBooks());
    expect(books.single.status, BookShelfStatus.finished);

    // Status change enqueues a bookshelf sync item.
    final queued =
        (await db.syncQueueDao.getAll()).map((e) => e.entityType).toSet();
    expect(queued, contains('bookshelf'));
  });

  test('removeBookFromLibrary clears all local records and the file folder',
      () async {
    await seedBook('b1');
    await db.progressDao.saveProgress(
      LocalReadingProgressCompanion.insert(bookId: 'b1', deviceId: 'dev-1'),
    );
    await db.notesDao.upsertNote(
      LocalNotesCompanion.insert(
        id: 'n1',
        bookId: 'b1',
        locatorType: 't',
        locatorValue: 'v',
        noteText: 'note',
      ),
    );
    await db.notesDao.upsertBookmark(
      LocalBookmarksCompanion.insert(
        id: 'm1',
        bookId: 'b1',
        locatorType: 't',
        locatorValue: 'v',
      ),
    );
    await db.sessionsDao.startSession(
      LocalReadingSessionsCompanion.insert(id: 's1', bookId: 'b1', mode: 'normal'),
    );
    await db.syncQueueDao.enqueue(
      SyncQueueCompanion.insert(
        id: 'q1',
        entityType: 'book',
        entityId: 'b1',
        operation: 'create',
      ),
    );
    final bookDir = Directory('${tmp.path}/books/b1')
      ..createSync(recursive: true);
    File('${bookDir.path}/b1.txt').writeAsStringSync('x');

    final result = await repo.removeBookFromLibrary('b1');

    expect(result, isA<Ok<void>>());
    expect(await db.booksDao.getById('b1'), isNull);
    expect(await db.bookshelfDao.getByBookId('b1'), isNull);
    expect(await db.progressDao.getByBookId('b1'), isNull);
    expect(await db.notesDao.getNotesForBook('b1'), isEmpty);
    expect(await db.notesDao.getBookmarksForBook('b1'), isEmpty);
    expect(await db.sessionsDao.getForBook('b1'), isEmpty);
    expect(await db.syncQueueDao.getAll(), isEmpty);
    expect(bookDir.existsSync(), isFalse);
  });
}
