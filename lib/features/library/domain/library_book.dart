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
    this.hasLocalFile = true,
    this.cloudBookId,
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

  /// False for cloud-shelf entries with no downloaded file (catalog adds):
  /// they open Book Detail, not the reader.
  final bool hasLocalFile;

  /// The Supabase books.id when known (navigates to catalog Book Detail).
  final String? cloudBookId;
}
