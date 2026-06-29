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

  /// Start offset of each chapter within [fullText] (chapters are joined by a
  /// 2-char `\n\n` separator). Used to map a TOC entry to a page.
  List<int> chapterStartOffsets() {
    final offsets = <int>[];
    var acc = 0;
    for (var i = 0; i < chapters.length; i++) {
      offsets.add(acc);
      acc += chapters[i].text.length;
      if (i < chapters.length - 1) acc += 2; // the '\n\n' join
    }
    return offsets;
  }
}
