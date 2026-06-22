/// A logical chapter of a book. TXT books have a single chapter; richer
/// formats (EPUB) split into many.
class ReaderChapter {
  const ReaderChapter({
    required this.index,
    required this.title,
    required this.text,
  });

  final int index;
  final String title;
  final String text;
}
