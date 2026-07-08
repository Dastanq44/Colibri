import 'package:flutter/widgets.dart';

import '../domain/reader_page.dart';

/// Pagination for the normal reader.
///
/// [paginate] is a fast char-count split used as an initial placeholder;
/// [paginateToFit] measures against the real viewport + font so each page
/// fills the screen without overflowing (no scrolling). Both record
/// start/end offsets so a page maps back to a saved locator.
class TextPaginationService {
  const TextPaginationService();

  static const int defaultTargetChars = 1500;

  /// Splits [text] into pages that each fit within [maxWidth] x [maxHeight]
  /// when laid out with [style] and [textScaler]. Greedy: packs as much as
  /// fits per page, then snaps the break back to a paragraph or word boundary
  /// so words are never cut. Offsets stay contiguous and cover all of [text].
  List<ReaderPage> paginateToFit(
    String text, {
    required double maxWidth,
    required double maxHeight,
    required TextStyle style,
    TextScaler textScaler = TextScaler.noScaling,
    int maxCharsPerPage = 3000,
  }) {
    if (text.isEmpty || maxWidth <= 0 || maxHeight <= 0) {
      return const <ReaderPage>[];
    }
    final painter = TextPainter(
      textDirection: TextDirection.ltr,
      textScaler: textScaler,
      maxLines: null,
    );

    bool fits(int start, int end) {
      painter.text = TextSpan(text: text.substring(start, end), style: style);
      painter.layout(maxWidth: maxWidth);
      return painter.height <= maxHeight;
    }

    final pages = <ReaderPage>[];
    final length = text.length;
    var start = 0;

    while (start < length) {
      final hi = (start + maxCharsPerPage).clamp(start + 1, length);
      // Largest end in (start, hi] whose laid-out height still fits.
      var lo = start + 1;
      var high = hi;
      var best = start + 1; // guarantee forward progress
      while (lo <= high) {
        final mid = lo + (high - lo) ~/ 2;
        if (fits(start, mid)) {
          best = mid;
          lo = mid + 1;
        } else {
          high = mid - 1;
        }
      }
      var end = best;
      if (end < length) {
        // Snap back to a paragraph (preferred) or word boundary in the second
        // half of the fitted window so we never cut a word.
        final minBreak = start + ((end - start) ~/ 2);
        final paragraph = text.lastIndexOf('\n\n', end);
        if (paragraph >= minBreak && paragraph > start) {
          end = paragraph + 2;
        } else {
          final space = text.lastIndexOf(' ', end - 1);
          if (space > start) end = space + 1;
        }
      }
      if (end <= start) end = (start + 1).clamp(start + 1, length);

      pages.add(ReaderPage(
        pageIndex: pages.length,
        text: text.substring(start, end),
        startOffset: start,
        endOffset: end,
      ));
      start = end;
    }
    return pages;
  }

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
