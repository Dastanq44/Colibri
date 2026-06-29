import 'dart:io';

import 'package:colibri/core/errors/failures.dart';
import 'package:colibri/core/platform/device_id_service.dart';
import 'package:colibri/core/result/result.dart';
import 'package:colibri/data/local/app_database.dart';
import 'package:colibri/data/repositories/local_reader_repository.dart';
import 'package:colibri/features/reader/domain/reader_document.dart';
import 'package:colibri/features/reader/domain/reader_locator.dart';
import 'package:colibri/features/reader/domain/reader_mode.dart';
import 'package:colibri/features/sync/data/local_sync_queue_repository.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late AppDatabase db;
  late Directory tmp;
  late LocalReaderRepository repo;

  setUp(() {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    tmp = Directory.systemTemp.createTempSync('colibri_reader');
    repo = LocalReaderRepository(
      db: db,
      deviceIdService: DeviceIdService(db.keyValueDao),
      syncQueue: LocalSyncQueueRepository(db),
    );
  });

  tearDown(() async {
    await db.close();
    if (tmp.existsSync()) tmp.deleteSync(recursive: true);
  });

  Future<void> seedBook(
    String id, {
    required String format,
    String? content,
  }) async {
    final path = '${tmp.path}/$id.$format';
    if (content != null) File(path).writeAsStringSync(content);
    await db.booksDao.upsertBook(
      LocalBooksCompanion.insert(
        id: id,
        sourceType: 'upload',
        format: format,
        title: 'Book $id',
        fileLocalPath: path,
      ),
    );
  }

  test('opens an imported TXT book and normalizes line endings', () async {
    await seedBook('b1', format: 'txt', content: 'Line one\r\nLine two');

    final doc = switch (await repo.openBook('b1')) {
      Ok(value: final d) => d,
      Err(failure: final f) => fail('expected success, got $f'),
    };

    expect(doc, isA<ReaderDocument>());
    expect(doc.format, 'txt');
    expect(doc.fullText, 'Line one\nLine two');
  });

  test('returns unsupported for PDF', () async {
    await seedBook('p1', format: 'pdf', content: '%PDF-1.7');
    final result = await repo.openBook('p1');
    expect((result as Err).failure, isA<UnsupportedFormatFailure>());
  });

  test('returns malformed failure for an invalid EPUB', () async {
    await seedBook('e1', format: 'epub', content: 'not a real zip');
    final result = await repo.openBook('e1');
    expect((result as Err).failure, isA<MalformedBookFailure>());
  });

  test('returns not found for a missing book', () async {
    final result = await repo.openBook('does-not-exist');
    expect((result as Err).failure, isA<NotFoundFailure>());
  });

  test('returns file-missing when the book file is gone', () async {
    await seedBook('b2', format: 'txt'); // no content -> file not created
    final result = await repo.openBook('b2');
    expect((result as Err).failure, isA<FileMissingFailure>());
  });

  test('saves and reloads the reading locator', () async {
    await seedBook('b1', format: 'txt', content: 'hello world');

    await repo.saveLocator(
      'b1',
      const ReaderLocator(
        locatorType: 'txt_offset',
        locatorValue: '0',
        pageNumber: 0,
        percent: 0,
      ),
    );

    final saved = switch (await repo.getSavedLocator('b1')) {
      Ok(value: final l) => l,
      Err() => null,
    };

    expect(saved, isNotNull);
    expect(saved!.pageNumber, 0);
    expect(saved.locatorType, 'txt_offset');
  });

  test('saves fast-mode position with token + paragraph data', () async {
    await seedBook('b1', format: 'txt', content: 'hello world');

    await repo.saveLocator(
      'b1',
      const ReaderLocator(
        locatorType: 'txt_offset',
        locatorValue: '42',
        paragraphIndex: 3,
        tokenIndex: 7,
        percent: 12.5,
      ),
      mode: ReaderMode.fast,
    );

    final saved = switch (await repo.getSavedLocator('b1')) {
      Ok(value: final l) => l,
      Err() => null,
    };

    expect(saved, isNotNull);
    expect(saved!.tokenIndex, 7);
    expect(saved.paragraphIndex, 3);
    expect(saved.locatorValue, '42');
  });

  test('opening a book stamps shelf last-opened and enqueues a bookshelf item',
      () async {
    await seedBook('b1', format: 'txt', content: 'hello');
    await db.bookshelfDao.upsertEntry(
      LocalBookshelfCompanion.insert(bookId: 'b1', status: 'reading'),
    );

    await repo.openBook('b1');

    final shelf = await db.bookshelfDao.getByBookId('b1');
    expect(shelf!.lastOpenedAt, isNotNull);
    final queued =
        (await db.syncQueueDao.getAll()).map((e) => e.entityType).toSet();
    expect(queued, contains('bookshelf'));
  });

  test('saving progress enqueues a single coalesced reading_progress item',
      () async {
    await seedBook('b1', format: 'txt', content: 'hello world');

    await repo.saveLocator(
      'b1',
      const ReaderLocator(
          locatorType: 'text_offset', locatorValue: '0', percent: 0),
    );
    await repo.saveLocator(
      'b1',
      const ReaderLocator(
          locatorType: 'text_offset', locatorValue: '5', percent: 10),
    );

    final items = (await db.syncQueueDao.getAll())
        .where((e) => e.entityType == 'reading_progress')
        .toList();
    expect(items, hasLength(1));
  });
}
