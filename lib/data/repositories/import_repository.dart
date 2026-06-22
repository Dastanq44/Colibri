import '../../core/result/result.dart';
import '../../features/import/domain/import_preview.dart';
import '../../features/import/domain/imported_book.dart';

/// Boundary for the local-first book import pipeline: pick → validate → copy +
/// checksum + metadata → local records. Cloud upload is added in a later phase.
abstract interface class ImportRepository {
  /// Opens the system file picker. Returns a [CanceledFailure] if dismissed.
  Future<Result<ImportPreview>> pickBookFile();

  /// Validates a picked file (format, size, readability).
  Future<Result<ImportPreview>> validatePickedFile(ImportPreview file);

  /// Copies the file into app storage and creates local book/shelf/progress
  /// records. Returns a [DuplicateFailure] if already imported.
  Future<Result<ImportedBook>> importPickedFile(ImportPreview file);
}
