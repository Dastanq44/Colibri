/// One paginated page of text with offsets back into the source text (used to
/// map a page to a saved locator and progress percent).
class ReaderPage {
  const ReaderPage({
    required this.pageIndex,
    required this.text,
    required this.startOffset,
    required this.endOffset,
  });

  final int pageIndex;
  final String text;

  /// Inclusive start / exclusive end character offsets in the source text.
  final int startOffset;
  final int endOffset;
}
