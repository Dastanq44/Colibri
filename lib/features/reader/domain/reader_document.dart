import 'reader_chapter.dart';

/// A loaded, readable book. Format-agnostic: the reader engine works on
/// chapters/text and never touches the file system directly.
class ReaderDocument {
  const ReaderDocument({
    required this.bookId,
    required this.title,
    required this.format,
    required this.chapters,
  });

  final String bookId;
  final String title;
  final String format;
  final List<ReaderChapter> chapters;

  /// Whole-book text (chapters joined). For TXT this is the single chapter.
  String get fullText => chapters.map((c) => c.text).join('\n\n');
}
