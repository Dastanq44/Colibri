import '../../../shared/models/book_format.dart';
import '../../../shared/models/bookshelf_status.dart';

/// A book as shown in "My Books" — a flattened view over the local books,
/// bookshelf, and progress tables.
class LibraryBook {
  const LibraryBook({
    required this.id,
    required this.title,
    required this.authorDisplay,
    required this.format,
    required this.status,
    required this.percent,
    required this.isFastModeSupported,
    this.lastOpenedAt,
  });

  final String id;
  final String title;
  final String authorDisplay;
  final BookFormat format;
  final BookShelfStatus status;

  /// Reading progress 0–100.
  final double percent;

  final bool isFastModeSupported;
  final DateTime? lastOpenedAt;
}
