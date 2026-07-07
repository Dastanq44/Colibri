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

  test('returns unsupported for PDF (openBook; page viewer path instead)',
      () async {
    await seedBook('p1', format: 'pdf', content: '%PDF-1.7');
    final result = await repo.openBook('p1');
    expect((result as Err).failure, isA<UnsupportedFormatFailure>());
  });

  group('openPdfBook', () {
    test('returns the file path and defaults to page 1', () async {
      await seedBook('p1', format: 'pdf', content: '%PDF-1.7');
      final source = ((await repo.openPdfBook('p1')) as Ok).value;
      expect(source.title, 'Book p1');
      expect(source.filePath, endsWith('p1.pdf'));
      expect(source.initialPageNumber, 1);
    });

    test('resumes at the saved pdf_page locator', () async {
      await seedBook('p1', format: 'pdf', content: '%PDF-1.7');
      await repo.saveLocator(
        'p1',
        const ReaderLocator(
          locatorType: 'pdf_page',
          locatorValue: '12',
          pageNumber: 12,
          percent: 40,
        ),
      );
      final source = ((await repo.openPdfBook('p1')) as Ok).value;
      expect(source.initialPageNumber, 12);
    });

    test('ignores a non-pdf locator left by another format', () async {
      await seedBook('p1', format: 'pdf', content: '%PDF-1.7');
      await repo.saveLocator(
        'p1',
        const ReaderLocator(
          locatorType: 'text_offset',
          locatorValue: '900',
          pageNumber: 3,
          percent: 10,
        ),
      );
      final source = ((await repo.openPdfBook('p1')) as Ok).value;
      expect(source.initialPageNumber, 1);
    });

    test('fails typed for a missing file and a non-pdf book', () async {
      await seedBook('gone', format: 'pdf'); // no content -> no file
      expect(((await repo.openPdfBook('gone')) as Err).failure,
          isA<FileMissingFailure>());

      await seedBook('t1', format: 'txt', content: 'hello');
      expect(((await repo.openPdfBook('t1')) as Err).failure,
          isA<UnsupportedFormatFailure>());
    });
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

  test('concurrent saves keep revisions strictly monotonic', () async {
    await seedBook('b1', format: 'txt', content: 'hello world');

    // Overlapping saves are real: page turns persist fire-and-forget and the
    // fast engine checkpoints on a timer. Each save must get its own revision.
    await Future.wait(<Future<void>>[
      for (var i = 0; i < 10; i++)
        repo.saveLocator(
          'b1',
          ReaderLocator(
            locatorType: 'text_offset',
            locatorValue: '$i',
            percent: i.toDouble(),
          ),
        ),
    ]);

    final row = await db.progressDao.getByBookId('b1');
    expect(row!.revision, 10);
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
