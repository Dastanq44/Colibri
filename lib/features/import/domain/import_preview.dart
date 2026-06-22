import '../../../shared/models/book_format.dart';

/// A picked file under consideration for import (before it is copied/saved).
class ImportPreview {
  const ImportPreview({
    required this.path,
    required this.fileName,
    required this.extension,
    required this.sizeBytes,
    this.format,
  });

  /// Absolute path to the externally-picked file (do not rely on it after
  /// import — the file is copied into app storage).
  final String path;

  /// Original file name, e.g. `My Book.epub`.
  final String fileName;

  /// Lowercase extension without a dot, e.g. `epub`.
  final String extension;

  final int sizeBytes;

  /// Resolved format, if recognized.
  final BookFormat? format;

  ImportPreview copyWith({BookFormat? format}) => ImportPreview(
        path: path,
        fileName: fileName,
        extension: extension,
        sizeBytes: sizeBytes,
        format: format ?? this.format,
      );
}
