import '../domain/reader_page.dart';

/// Simple, testable logical pagination by approximate character count.
///
/// This is intentionally not pixel-accurate layout pagination (that comes in a
/// later phase). It tries to break on paragraph/word boundaries and records
/// start/end offsets so a page maps back to a saved locator.
class TextPaginationService {
  const TextPaginationService();

  static const int defaultTargetChars = 1500;

  List<ReaderPage> paginate(
    String text, {
    int targetChars = defaultTargetChars,
  }) {
    if (text.trim().isEmpty) return const <ReaderPage>[];

    final pages = <ReaderPage>[];
    final length = text.length;
    var start = 0;

    while (start < length) {
      var end = start + targetChars;
      if (end >= length) {
        end = length;
      } else {
        // Prefer a paragraph break in the second half of the window.
        final minBreak = start + (targetChars ~/ 2);
        final paragraph = text.lastIndexOf('\n\n', end);
        if (paragraph >= minBreak) {
          end = paragraph + 2;
        } else {
          final space = text.lastIndexOf(' ', end);
          if (space > start) end = space + 1;
        }
      }
      // Guard against non-progress (e.g. a very long unbroken token).
      if (end <= start) end = (start + targetChars).clamp(start + 1, length);

      pages.add(
        ReaderPage(
          pageIndex: pages.length,
          text: text.substring(start, end),
          startOffset: start,
          endOffset: end,
        ),
      );
      start = end;
    }

    return pages;
  }
}
