import 'dart:io';

import 'package:drift/drift.dart' show Value;
import 'package:file_picker/file_picker.dart';

import '../../core/errors/failures.dart';
import '../../core/platform/device_id_service.dart';
import '../../core/result/result.dart';
import '../../core/utils/id_generator.dart';
import '../../features/import/data/book_file_validator.dart';
import '../../features/import/data/book_metadata_service.dart';
import '../../features/import/data/checksum_service.dart';
import '../../features/import/data/file_storage_service.dart';
import '../../features/import/domain/import_preview.dart';
import '../../features/import/domain/imported_book.dart';
import '../../features/reader/data/epub_extractor.dart';
import '../../features/sync/data/local_sync_queue_repository.dart';
import '../../features/sync/domain/sync_operation.dart';
import '../../shared/models/book_format.dart';
import '../../shared/models/bookshelf_status.dart';
import '../local/app_database.dart';
import '../local/sync_status.dart';
import 'import_repository.dart';

/// Local-first [ImportRepository]. No cloud upload — files stay on device and
/// records go into Drift. Newly imported books default to "reading".
class LocalImportRepository implements ImportRepository {
  LocalImportRepository({
    required AppDatabase db,
    required FileStorageService storage,
    required ChecksumService checksum,
    required BookFileValidator validator,
    required BookMetadataService metadata,
    required DeviceIdService deviceIdService,
    required LocalSyncQueueRepository syncQueue,
    EpubExtractor epubExtractor = const EpubExtractor(),
  })  : _db = db,
        _storage = storage,
        _checksum = checksum,
        _validator = validator,
        _metadata = metadata,
        _deviceIdService = deviceIdService,
        _sync = syncQueue,
        _epub = epubExtractor;

  final AppDatabase _db;
  final FileStorageService _storage;
  final ChecksumService _checksum;
  final BookFileValidator _validator;
  final BookMetadataService _metadata;
  final DeviceIdService _deviceIdService;
  final LocalSyncQueueRepository _sync;
  final EpubExtractor _epub;

  static const List<String> _allowedExtensions = <String>['epub', 'txt', 'pdf'];

  @override
  Future<Result<ImportPreview>> pickBookFile() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: _allowedExtensions,
      );
      if (result == null || result.files.isEmpty) {
        return const Err(CanceledFailure());
      }
      final file = result.files.single;
      final path = file.path;
      if (path == null) return const Err(FileMissingFailure());
      return Ok(
        ImportPreview(
          path: path,
          fileName: file.name,
          extension: (file.extension ?? '').toLowerCase(),
          sizeBytes: file.size,
          format: _validator.formatForFileName(file.name),
        ),
      );
    } catch (e) {
      return Err(UnknownFailure(e.toString()));
    }
  }

  @override
  Future<Result<ImportPreview>> validatePickedFile(ImportPreview file) async {
    final invalid = _validator.validatePreview(file);
    if (invalid != null) return Err(invalid);
    if (!await File(file.path).exists()) return const Err(FileMissingFailure());
    return Ok(file.copyWith(format: _validator.formatForFileName(file.fileName)));
  }

  @override
  Future<Result<ImportedBook>> importPickedFile(ImportPreview file) async {
    // Defensive re-validation.
    final invalid = _validator.validatePreview(file);
    if (invalid != null) return Err(invalid);

    final source = File(file.path);
    if (!await source.exists()) return const Err(FileMissingFailure());

    final format = file.format ?? _validator.formatForFileName(file.fileName);
    if (format == null) return const Err(UnsupportedFormatFailure());

    try {
      // Duplicate detection by content checksum.
      final checksum = await _checksum.sha256OfFile(source);
      final existing = await _db.booksDao.getByChecksum(checksum);
      if (existing != null) return const Err(DuplicateFailure());

      final bookId = IdGenerator.newId();

      // Copy into app-controlled storage.
      final String localPath;
      try {
        localPath = await _storage.copyIntoBookStorage(
          bookId: bookId,
          sourcePath: file.path,
          fileName: file.fileName,
        );
      } catch (_) {
        return const Err(StorageFailure('Could not copy the file.'));
      }

      final meta = _metadata.extract(fileName: file.fileName, format: format);

      // For EPUB, try to improve metadata from the OPF and confirm there is
      // extractable text (so fast mode is enabled and status is `ready`).
      var title = meta.title;
      var authorDisplay = meta.authorDisplay;
      var language = '';
      var isFastModeSupported = meta.isFastModeSupported;
      var textReadyStatus = meta.textReadyStatus;
      if (format == BookFormat.epub) {
        try {
          final epub = _epub.extract(await File(localPath).readAsBytes());
          if (epub != null && epub.chapters.isNotEmpty) {
            if (epub.title != null && epub.title!.trim().isNotEmpty) {
              title = epub.title!.trim();
            }
            if (epub.author != null && epub.author!.trim().isNotEmpty) {
              authorDisplay = epub.author!.trim();
            }
            language = epub.language?.trim() ?? '';
            isFastModeSupported = true;
            textReadyStatus = 'ready';
          }
          // Malformed/empty EPUB keeps the fallback metadata; it still imports
          // and shows a friendly message when opened.
        } catch (_) {
          // Ignore — keep fallback metadata.
        }
      }

      final deviceId = await _deviceIdService.getOrCreate();

      try {
        // All three local writes succeed or none do.
        await _db.transaction(() async {
          await _db.booksDao.upsertBook(
            LocalBooksCompanion.insert(
              id: bookId,
              sourceType: 'upload',
              format: format.wire,
              title: title,
              fileLocalPath: localPath,
              authorDisplay: Value(authorDisplay),
              language: Value(language),
              checksumSha256: Value(checksum),
              isFastModeSupported: Value(isFastModeSupported),
              textReadyStatus: Value(textReadyStatus),
              syncStatus: const Value(SyncStatus.pendingUpload),
            ),
          );
          await _db.bookshelfDao.upsertEntry(
            LocalBookshelfCompanion.insert(
              bookId: bookId,
              status: BookShelfStatus.reading.wire,
              syncStatus: const Value(SyncStatus.pendingUpload),
            ),
          );
          await _db.progressDao.saveProgress(
            LocalReadingProgressCompanion.insert(
              bookId: bookId,
              deviceId: deviceId,
            ),
          );
        });
      } catch (e) {
        // Transaction rolled back; remove the copied file so a failed import
        // leaves no orphan.
        await _storage.deleteBookStorage(bookId);
        return Err(StorageFailure('Could not save the book (${e.runtimeType}).'));
      }

      // Enqueue cloud sync work (processed only on manual sign-in + sync).
      await _sync.enqueueBookCreate(bookId);
      await _sync.enqueueBookFileUpload(bookId);
      await _sync.enqueueBookshelf(bookId, operation: SyncOperation.create);

      return Ok(
        ImportedBook(
          bookId: bookId,
          title: title,
          authorDisplay: authorDisplay,
          format: format,
        ),
      );
    } catch (e) {
      return Err(UnknownFailure(e.toString()));
    }
  }
}
