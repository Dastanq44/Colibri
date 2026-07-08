import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

/// Copies imported files into an app-controlled folder so reading works
/// offline and never depends on the original external path.
///
/// Layout: `<app documents>/books/<bookId>/<safe file name>`.
class FileStorageService {
  FileStorageService({Directory? baseDirectory}) : _baseOverride = baseDirectory;

  /// Optional base dir override (used by tests to point at a temp directory).
  final Directory? _baseOverride;

  Future<Directory> _booksRoot() async {
    final base = _baseOverride ?? await getApplicationDocumentsDirectory();
    return Directory(p.join(base.path, 'books'));
  }

  /// Copies [sourcePath] into this book's storage folder and returns the new
  /// local path.
  Future<String> copyIntoBookStorage({
    required String bookId,
    required String sourcePath,
    required String fileName,
  }) async {
    final root = await _booksRoot();
    final destDir = Directory(p.join(root.path, bookId));
    await destDir.create(recursive: true);
    final destPath = p.join(destDir.path, sanitizeFileName(fileName));
    await File(sourcePath).copy(destPath);
    return destPath;
  }

  /// Writes a book's cover image next to its file
  /// (`books/<bookId>/cover.<ext>`) so it is removed together with the book.
  /// Returns the saved path.
  Future<String> saveCoverBytes({
    required String bookId,
    required List<int> bytes,
    required String extension,
  }) async {
    final root = await _booksRoot();
    final destDir = Directory(p.join(root.path, bookId));
    await destDir.create(recursive: true);
    final destPath = p.join(destDir.path, 'cover.$extension');
    await File(destPath).writeAsBytes(bytes, flush: true);
    return destPath;
  }

  /// Best-effort removal of a book's storage folder.
  Future<void> deleteBookStorage(String bookId) async {
    final root = await _booksRoot();
    final dir = Directory(p.join(root.path, bookId));
    if (await dir.exists()) {
      await dir.delete(recursive: true);
    }
  }

  /// Strips any directory part and replaces unsafe characters so the on-disk
  /// name is portable (the original name is still kept as the book title).
  static String sanitizeFileName(String fileName) {
    final base = p.basename(fileName);
    final cleaned = base.replaceAll(RegExp(r'[^A-Za-z0-9._-]'), '_');
    return cleaned.isEmpty ? 'book' : cleaned;
  }
}
