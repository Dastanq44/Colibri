import 'dart:convert';
import 'dart:io';

import 'package:drift/drift.dart' show Value;

import '../../core/errors/failures.dart';
import '../../core/platform/device_id_service.dart';
import '../../core/result/result.dart';
import '../../features/reader/data/epub_extractor.dart';
import '../../features/reader/domain/pdf_book_source.dart';
import '../../features/reader/domain/reader_chapter.dart';
import '../../features/reader/domain/reader_document.dart';
import '../../features/reader/domain/reader_locator.dart';
import '../../features/reader/domain/reader_locator_types.dart';
import '../../features/reader/domain/reader_mode.dart';
import '../../features/sync/data/local_sync_queue_repository.dart';
import '../../shared/models/book_format.dart';
import '../local/app_database.dart';
import '../local/sync_status.dart';
import 'reader_repository.dart';

/// Local-first [ReaderRepository]. Loads book text from on-device storage and
/// reads/writes reading progress via Drift. TXT and extracted EPUB text are
/// supported; PDF is unsupported for now.
class LocalReaderRepository implements ReaderRepository {
  LocalReaderRepository({
    required AppDatabase db,
    required DeviceIdService deviceIdService,
    required LocalSyncQueueRepository syncQueue,
    EpubExtractor epubExtractor = const EpubExtractor(),
  })  : _db = db,
        _deviceIdService = deviceIdService,
        _sync = syncQueue,
        _epub = epubExtractor;

  final AppDatabase _db;
  final DeviceIdService _deviceIdService;
  final LocalSyncQueueRepository _sync;
  final EpubExtractor _epub;

  /// Stamps book + shelf last-opened and marks the shelf row for sync.
  Future<void> _markOpened(String bookId) async {
    await _db.booksDao.updateLastOpened(bookId);
    await _db.bookshelfDao.markOpened(bookId);
    await _sync.enqueueBookshelf(bookId);
  }

  @override
  Future<Result<ReaderDocument>> openBook(String bookId) async {
    final book = await _db.booksDao.getById(bookId);
    if (book == null) return const Err(NotFoundFailure('Book not found.'));

    final format = BookFormat.fromWire(book.format);
    switch (format) {
      case BookFormat.txt:
        return _openTxt(book);
      case BookFormat.epub:
        return _openEpub(book);
      case BookFormat.pdf:
        // PDFs are page-rendered, not extracted to a text document — the
        // controller falls back to [openPdfBook] on this failure.
        return const Err(
          UnsupportedFormatFailure('PDFs open in the page viewer.'),
        );
    }
  }

  @override
  Future<Result<PdfBookSource>> openPdfBook(String bookId) async {
    final book = await _db.booksDao.getById(bookId);
    if (book == null) return const Err(NotFoundFailure('Book not found.'));
    if (BookFormat.fromWire(book.format) != BookFormat.pdf) {
      return const Err(UnsupportedFormatFailure('Not a PDF book.'));
    }
    if (!await File(book.fileLocalPath).exists()) {
      return const Err(FileMissingFailure('The book file is missing.'));
    }

    await _markOpened(book.id);

    var initialPage = 1;
    final progress = await _db.progressDao.getByBookId(bookId);
    if (progress != null && progress.locatorType == ReaderLocatorTypes.pdfPage) {
      initialPage =
          progress.pageNumber ?? int.tryParse(progress.locatorValue) ?? 1;
      if (initialPage < 1) initialPage = 1;
    }
    return Ok(
      PdfBookSource(
        bookId: book.id,
        title: book.title,
        filePath: book.fileLocalPath,
        initialPageNumber: initialPage,
      ),
    );
  }

  Future<Result<ReaderDocument>> _openEpub(LocalBook book) async {
    final file = File(book.fileLocalPath);
    if (!await file.exists()) {
      return const Err(FileMissingFailure('The book file is missing.'));
    }
    EpubExtractionResult? result;
    try {
      result = _epub.extract(await file.readAsBytes());
    } catch (_) {
      result = null;
    }
    if (result == null) {
      return const Err(MalformedBookFailure('Could not read this EPUB file.'));
    }
    if (result.chapters.isEmpty) {
      return const Err(EmptyBookFailure('No readable text was found.'));
    }

    await _markOpened(book.id);

    final title = (result.title != null && result.title!.trim().isNotEmpty)
        ? result.title!.trim()
        : book.title;
    return Ok(
      ReaderDocument(
        bookId: book.id,
        title: title,
        format: BookFormat.epub.wire,
        chapters: result.chapters,
      ),
    );
  }

  Future<Result<ReaderDocument>> _openTxt(LocalBook book) async {
    final file = File(book.fileLocalPath);
    if (!await file.exists()) {
      return const Err(FileMissingFailure('The book file is missing.'));
    }
    try {
      final bytes = await file.readAsBytes();
      // Decode tolerant of malformed bytes, then normalize line endings.
      final raw = utf8.decode(bytes, allowMalformed: true);
      final text = raw.replaceAll('\r\n', '\n').replaceAll('\r', '\n');

      // Stamp last-opened (book + shelf) for sync readiness.
      await _markOpened(book.id);

      return Ok(
        ReaderDocument(
          bookId: book.id,
          title: book.title,
          format: BookFormat.txt.wire,
          chapters: <ReaderChapter>[
            ReaderChapter(index: 0, title: book.title, text: text),
          ],
        ),
      );
    } catch (e) {
      return Err(UnknownFailure('Could not read the book: $e'));
    }
  }

  @override
  Future<Result<ReaderLocator?>> getSavedLocator(String bookId) async {
    try {
      final progress = await _db.progressDao.getByBookId(bookId);
      if (progress == null) return const Ok(null);
      return Ok(
        ReaderLocator(
          locatorType: progress.locatorType,
          locatorValue: progress.locatorValue,
          chapterIndex: progress.chapterIndex,
          pageNumber: progress.pageNumber,
          paragraphIndex: progress.paragraphIndex,
          tokenIndex: progress.tokenIndex,
          percent: progress.percent,
        ),
      );
    } catch (e) {
      return Err(StorageFailure(e.toString()));
    }
  }

  @override
  Future<Result<void>> saveLocator(
    String bookId,
    ReaderLocator locator, {
    ReaderMode mode = ReaderMode.normal,
  }) async {
    try {
      final deviceId = await _deviceIdService.getOrCreate();
      // One transaction: keeps the read-increment-write atomic (revisions stay
      // strictly monotonic under concurrent saves) and the queued snapshot
      // consistent with the row it was built from.
      await _db.transaction(() async {
        final existing = await _db.progressDao.getByBookId(bookId);
        final nextRevision = (existing?.revision ?? 0) + 1;

        await _db.progressDao.saveProgress(
          LocalReadingProgressCompanion.insert(
            bookId: bookId,
            deviceId: deviceId,
            locatorType: Value(locator.locatorType),
            locatorValue: Value(locator.locatorValue),
            chapterIndex: Value(locator.chapterIndex),
            pageNumber: Value(locator.pageNumber),
            paragraphIndex: Value(locator.paragraphIndex),
            tokenIndex: Value(locator.tokenIndex),
            percent: Value(locator.percent),
            mode: Value(mode.wire),
            revision: Value(nextRevision),
            updatedAt: Value(_nowIso()),
            syncStatus: const Value(SyncStatus.pendingUpdate),
          ),
        );
        // Coalesced: one pending reading_progress item per book (fast-mode
        // playback won't create hundreds of queue rows).
        await _sync.enqueueProgressUpdate(bookId);
      });
      return const Ok(null);
    } catch (e) {
      return Err(StorageFailure(e.toString()));
    }
  }

  String _nowIso() => DateTime.now().toUtc().toIso8601String();
}
