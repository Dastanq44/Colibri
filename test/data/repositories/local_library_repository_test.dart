import 'dart:convert';
import 'dart:io';

import 'package:colibri/core/errors/failures.dart';
import 'package:colibri/core/result/result.dart';
import 'package:colibri/data/local/app_database.dart';
import 'package:colibri/data/repositories/local_library_repository.dart';
import 'package:colibri/features/import/data/file_storage_service.dart';
import 'package:colibri/features/library/domain/library_book.dart';
import 'package:colibri/features/sync/data/local_sync_queue_repository.dart';
import 'package:colibri/shared/models/bookshelf_status.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

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
    // Annotation queue rows are keyed by the annotation id, not the book id —
    // removal must clean these too or their snapshots upload after deletion.
    await db.syncQueueDao.enqueue(
      SyncQueueCompanion.insert(
        id: 'q2',
        entityType: 'note',
        entityId: 'n1',
        operation: 'update',
      ),
    );
    await db.syncQueueDao.enqueue(
      SyncQueueCompanion.insert(
        id: 'q3',
        entityType: 'bookmark',
        entityId: 'm1',
        operation: 'update',
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

  group('refreshFromCloud', () {
    const cloudId = '00000000-0000-0000-0000-0000000000c1';
    const localId = '000000000000000000000000000000c1';

    Future<SupabaseClient> signedInClient(String url) async {
      final client = SupabaseClient(url, 'anon-key');
      await client.auth.setInitialSession(jsonEncode(<String, dynamic>{
        'access_token': 'header.payload.signature',
        'token_type': 'bearer',
        'user': <String, dynamic>{'id': 'user-a'},
      }));
      return client;
    }

    Future<HttpServer> shelfServer() async {
      final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      addTearDown(() => server.close(force: true));
      server.listen((req) {
        req.response
          ..statusCode = 200
          ..headers.contentType = ContentType.json
          ..write(jsonEncode(<Map<String, dynamic>>[
            <String, dynamic>{
              'book_id': cloudId,
              'status': 'want_to_read',
              'books': <String, dynamic>{
                'id': cloudId,
                'title': 'Cloud Book',
                'format': 'epub',
                'language': 'en',
                'is_fast_mode_supported': true,
                'book_authors': <Map<String, dynamic>>[
                  <String, dynamic>{
                    'authors': <String, dynamic>{'name': 'Cloud Author'}
                  },
                ],
              },
            },
          ]));
        req.response.close();
      });
      return server;
    }

    test('requires backend + session', () async {
      expect(((await repo.refreshFromCloud()) as Err).failure,
          isA<BackendUnavailableFailure>());

      final client = SupabaseClient('http://127.0.0.1:1', 'anon-key');
      addTearDown(() => client.dispose());
      final signedOut = LocalLibraryRepository(
        db,
        FileStorageService(baseDirectory: tmp),
        LocalSyncQueueRepository(db),
        client: client,
      );
      expect(((await signedOut.refreshFromCloud()) as Err).failure,
          isA<UnauthorizedFailure>());
    });

    test('pulls missing cloud entries as file-less catalog books, idempotently',
        () async {
      final server = await shelfServer();
      final client = await signedInClient('http://127.0.0.1:${server.port}');
      addTearDown(() => client.dispose());
      final cloudRepo = LocalLibraryRepository(
        db,
        FileStorageService(baseDirectory: tmp),
        LocalSyncQueueRepository(db),
        client: client,
      );

      expect(((await cloudRepo.refreshFromCloud()) as Ok).value, 1);

      final books = ((await cloudRepo.getMyBooks()) as Ok).value;
      final book = books.single;
      expect(book.id, localId);
      expect(book.title, 'Cloud Book');
      expect(book.status, BookShelfStatus.wantToRead);
      expect(book.hasLocalFile, isFalse);
      expect(book.cloudBookId, cloudId);

      // Second pull adds nothing and leaves the entry untouched.
      expect(((await cloudRepo.refreshFromCloud()) as Ok).value, 0);

      // A local status change survives further refreshes (local-first).
      await cloudRepo.updateBookStatus(localId, BookShelfStatus.reading);
      await cloudRepo.refreshFromCloud();
      final after = ((await cloudRepo.getMyBooks()) as Ok).value.single;
      expect(after.status, BookShelfStatus.reading);
    });
  });
}
