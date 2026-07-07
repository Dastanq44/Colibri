/// What the PDF viewer needs to open a book: the local file and where to
/// resume. PDFs are rendered as pages (TASK-0704), not extracted to text.
class PdfBookSource {
  const PdfBookSource({
    required this.bookId,
    required this.title,
    required this.filePath,
    required this.initialPageNumber,
  });

  final String bookId;
  final String title;
  final String filePath;

  /// 1-based page to resume at (1 when the book was never opened).
  final int initialPageNumber;
}
