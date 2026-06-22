import '../../../shared/models/book_format.dart';

/// Result of a successful local import.
class ImportedBook {
  const ImportedBook({
    required this.bookId,
    required this.title,
    required this.authorDisplay,
    required this.format,
  });

  final String bookId;
  final String title;
  final String authorDisplay;
  final BookFormat format;
}
