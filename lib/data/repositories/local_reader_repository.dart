import 'dart:convert';
import 'dart:io';

import 'package:drift/drift.dart' show Value;

import '../../core/errors/failures.dart';
import '../../core/platform/device_id_service.dart';
import '../../core/result/result.dart';
import '../../features/reader/domain/reader_chapter.dart';
import '../../features/reader/domain/reader_document.dart';
import '../../features/reader/domain/reader_locator.dart';
import '../../features/reader/domain/reader_mode.dart';
import '../../shared/models/book_format.dart';
import '../local/app_database.dart';
import '../local/sync_status.dart';
import 'reader_repository.dart';

/// Local-first [ReaderRepository]. Loads book text from on-device storage and
/// reads/writes reading progress via Drift. TXT is fully supported; EPUB and
/// PDF return a clear unsupported failure for now.
class LocalReaderRepository implements ReaderRepository {
  LocalReaderRepository({
    required AppDatabase db,
    required DeviceIdService deviceIdService,
  })  : _db = db,
        _deviceIdService = deviceIdService;

  final AppDatabase _db;
  final DeviceIdService _deviceIdService;

  @override
  Future<Result<ReaderDocument>> openBook(String bookId) async {
    final book = await _db.booksDao.getById(bookId);
    if (book == null) return const Err(NotFoundFailure('Book not found.'));

    final format = BookFormat.fromWire(book.format);
    switch (format) {
      case BookFormat.txt:
        return _openTxt(book);
      case BookFormat.epub:
        return const Err(
          UnsupportedFormatFailure('EPUB reader is not implemented yet.'),
        );
      case BookFormat.pdf:
        return const Err(
          UnsupportedFormatFailure('PDF reader is not implemented yet.'),
        );
    }
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

      // Stamp last-opened.
      await _db.booksDao.updateLastOpened(book.id);

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
  Future<Result<void>> saveLocator(String bookId, ReaderLocator locator) async {
    try {
      final deviceId = await _deviceIdService.getOrCreate();
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
          percent: Value(locator.percent),
          mode: Value(ReaderMode.normal.wire),
          revision: Value(nextRevision),
          updatedAt: Value(_nowIso()),
          syncStatus: const Value(SyncStatus.pendingUpdate),
        ),
      );
      return const Ok(null);
    } catch (e) {
      return Err(StorageFailure(e.toString()));
    }
  }

  String _nowIso() => DateTime.now().toUtc().toIso8601String();
}
