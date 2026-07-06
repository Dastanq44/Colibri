import '../../../core/errors/failures.dart';
import '../../../shared/models/book_format.dart';
import '../domain/import_preview.dart';

/// Pure, testable validation of a picked file (format + size). File-system
/// existence checks live in the repository (they need I/O).
class BookFileValidator {
  const BookFileValidator();

  /// MVP maximum import size (100 MB).
  static const int maxFileSizeBytes = 100 * 1024 * 1024;

  /// The format for a file name, or `null` if its extension is unsupported.
  BookFormat? formatForFileName(String fileName) =>
      BookFormat.fromExtension(_extension(fileName));

  bool isSupported(String fileName) => formatForFileName(fileName) != null;

  /// Returns a typed [Failure] if [preview] is invalid, otherwise `null`.
  Failure? validatePreview(ImportPreview preview) {
    if (formatForFileName(preview.fileName) == null) {
      return const UnsupportedFormatFailure();
    }
    // Zero-byte files have no readable text; rejecting them here also avoids
    // a bogus duplicate match downstream (all empty files share one SHA-256).
    if (preview.sizeBytes <= 0) {
      return const EmptyBookFailure();
    }
    if (preview.sizeBytes > maxFileSizeBytes) {
      return const FileTooLargeFailure();
    }
    return null;
  }

  String _extension(String fileName) {
    final dot = fileName.lastIndexOf('.');
    return dot >= 0 ? fileName.substring(dot + 1) : '';
  }
}
