/// A single in-book search hit: where it starts and a display snippet.
class BookSearchMatch {
  const BookSearchMatch({
    required this.offset,
    required this.snippet,
    required this.percent,
  });

  /// Character offset of the match in the book's original full text (the
  /// jump target used by the reader).
  final int offset;

  /// The match with surrounding context, single-line, ellipsized at the ends.
  final String snippet;

  /// Approximate position in the book, 0–100.
  final double percent;
}

/// The outcome of an in-book search: the (possibly capped) matches plus
/// whether more matches exist beyond the cap.
class BookSearchResult {
  const BookSearchResult({required this.matches, required this.truncated});

  static const BookSearchResult empty =
      BookSearchResult(matches: <BookSearchMatch>[], truncated: false);

  final List<BookSearchMatch> matches;

  /// True when the scan stopped at the cap — later occurrences exist but are
  /// not listed. The UI must say so, or a capped list reads as "no more".
  final bool truncated;
}

/// Case-insensitive, whitespace-flexible plain-text search (reader menu
/// "Search in book").
///
/// Book text keeps its source line wraps (hard-wrapped TXT, pretty-printed
/// EPUB), so a phrase the user *sees* as `quick brown` may be stored as
/// `quick\nbrown`. Matching runs on a whitespace-collapsed copy of the text
/// (every run of whitespace becomes one space) with a map back to original
/// offsets, so jumps stay exact. Cyrillic works via Dart's
/// locale-independent `toLowerCase`, which never changes UTF-16 length.
/// Pure and synchronous — testable without UI.
BookSearchResult searchBookText(
  String text,
  String query, {
  int maxResults = 100,
  int contextChars = 40,
}) {
  final needle = _normalizeWhitespace(query).text.trim().toLowerCase();
  if (needle.isEmpty || text.isEmpty) return BookSearchResult.empty;

  final normalized = _normalizeWhitespace(text);
  final haystack = normalized.text.toLowerCase();

  final matches = <BookSearchMatch>[];
  var truncated = false;
  var from = 0;
  while (true) {
    final at = haystack.indexOf(needle, from);
    if (at < 0) break;
    if (matches.length >= maxResults) {
      truncated = true;
      break;
    }
    matches.add(
      BookSearchMatch(
        offset: normalized.originalOffsets[at],
        snippet:
            _snippet(normalized.text, at, needle.length, contextChars),
        percent: text.length <= 1
            ? 0
            : (normalized.originalOffsets[at] / text.length) * 100,
      ),
    );
    from = at + needle.length;
  }
  return BookSearchResult(matches: matches, truncated: truncated);
}

class _Normalized {
  const _Normalized(this.text, this.originalOffsets);

  final String text;

  /// For each code unit of [text], its offset in the original string.
  final List<int> originalOffsets;
}

bool _isWhitespace(int codeUnit) =>
    codeUnit == 0x20 ||
    (codeUnit >= 0x09 && codeUnit <= 0x0D) ||
    codeUnit == 0xA0;

/// Collapses every whitespace run to a single space, remembering where each
/// kept code unit came from.
_Normalized _normalizeWhitespace(String text) {
  final buffer = StringBuffer();
  final offsets = <int>[];
  var inWhitespace = false;
  for (var i = 0; i < text.length; i++) {
    final unit = text.codeUnitAt(i);
    if (_isWhitespace(unit)) {
      if (!inWhitespace) {
        buffer.writeCharCode(0x20);
        offsets.add(i);
        inWhitespace = true;
      }
    } else {
      buffer.writeCharCode(unit);
      offsets.add(i);
      inWhitespace = false;
    }
  }
  return _Normalized(buffer.toString(), offsets);
}

String _snippet(String text, int at, int matchLength, int contextChars) {
  var start = (at - contextChars).clamp(0, text.length);
  var end = (at + matchLength + contextChars).clamp(0, text.length);
  // Never split a surrogate pair at the window edges (would render U+FFFD).
  if (start > 0 && _isLowSurrogate(text.codeUnitAt(start))) start--;
  if (end < text.length && _isLowSurrogate(text.codeUnitAt(end))) end++;
  final raw = text.substring(start, end).trim();
  final prefix = start > 0 ? '…' : '';
  final suffix = end < text.length ? '…' : '';
  return '$prefix$raw$suffix';
}

bool _isLowSurrogate(int codeUnit) =>
    codeUnit >= 0xDC00 && codeUnit <= 0xDFFF;
