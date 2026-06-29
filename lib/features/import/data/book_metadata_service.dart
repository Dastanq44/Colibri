import '../../../shared/models/book_format.dart';

/// Minimal metadata extracted at import time. Kept simple and robust — never
/// fatal. Richer parsing (real EPUB metadata, PDF text-layer detection) lands
/// with the reader phases.
class BookMetadata {
  const BookMetadata({
    required this.title,
    required this.authorDisplay,
    required this.isFastModeSupported,
    required this.textReadyStatus,
  });

  final String title;
  final String authorDisplay;
  final bool isFastModeSupported;

  /// One of: `ready` | `pending` | `unsupported`.
  final String textReadyStatus;
}

/// Derives basic [BookMetadata] from a file name + format — the title falls
/// back to the file name. This is the first-pass fallback; EPUB import
/// additionally upgrades title/author/language via OPF extraction (see
/// `LocalImportRepository`).
class BookMetadataService {
  const BookMetadataService();

  BookMetadata extract({
    required String fileName,
    required BookFormat format,
  }) {
    final title = _titleFromFileName(fileName);
    return switch (format) {
      // TXT is linear text -> fast mode ready immediately.
      BookFormat.txt => BookMetadata(
          title: title,
          authorDisplay: '',
          isFastModeSupported: true,
          textReadyStatus: 'ready',
        ),
      // EPUB text extraction is implemented in a later phase.
      BookFormat.epub => BookMetadata(
          title: title,
          authorDisplay: '',
          isFastModeSupported: true,
          textReadyStatus: 'pending',
        ),
      // PDF fast mode requires a usable text layer (not detected in MVP).
      BookFormat.pdf => BookMetadata(
          title: title,
          authorDisplay: '',
          isFastModeSupported: false,
          textReadyStatus: 'unsupported',
        ),
    };
  }

  String _titleFromFileName(String fileName) {
    final dot = fileName.lastIndexOf('.');
    final name = dot > 0 ? fileName.substring(0, dot) : fileName;
    return name.trim().isEmpty ? fileName : name.trim();
  }
}
