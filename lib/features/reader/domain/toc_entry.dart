/// A table-of-contents entry. For TXT this is a single entry; for EPUB it is
/// one entry per spine chapter. [startOffset] maps into the document's full
/// text so tapping it can jump to the right page.
class TocEntry {
  const TocEntry({
    required this.title,
    required this.chapterIndex,
    required this.startOffset,
  });

  final String title;
  final int chapterIndex;
  final int startOffset;
}
