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
import '../../shared/models/bookshelf_status.dart';
import '../local/app_database.dart';
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
  })  : _db = db,
        _storage = storage,
        _checksum = checksum,
        _validator = validator,
        _metadata = metadata,
        _deviceIdService = deviceIdService;

  final AppDatabase _db;
  final FileStorageService _storage;
  final ChecksumService _checksum;
  final BookFileValidator _validator;
  final BookMetadataService _metadata;
  final DeviceIdService _deviceIdService;

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
      final deviceId = await _deviceIdService.getOrCreate();

      try {
        // All three local writes succeed or none do.
        await _db.transaction(() async {
          await _db.booksDao.upsertBook(
            LocalBooksCompanion.insert(
              id: bookId,
              sourceType: 'upload',
              format: format.wire,
              title: meta.title,
              fileLocalPath: localPath,
              authorDisplay: Value(meta.authorDisplay),
              checksumSha256: Value(checksum),
              isFastModeSupported: Value(meta.isFastModeSupported),
              textReadyStatus: Value(meta.textReadyStatus),
            ),
          );
          await _db.bookshelfDao.upsertEntry(
            LocalBookshelfCompanion.insert(
              bookId: bookId,
              status: BookShelfStatus.reading.wire,
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

      return Ok(
        ImportedBook(
          bookId: bookId,
          title: meta.title,
          authorDisplay: meta.authorDisplay,
          format: format,
        ),
      );
    } catch (e) {
      return Err(UnknownFailure(e.toString()));
    }
  }
}
