import '../domain/fast_token.dart';

/// Word-level tokenizer for TXT fast mode. Splits on whitespace (keeping
/// punctuation attached to words), tracks paragraph boundaries (blank lines),
/// and preserves source offsets. Works for Cyrillic and Latin text.
class FastModeTokenizer {
  const FastModeTokenizer();

  static final RegExp _word = RegExp(r'\S+');
  static final RegExp _blankLine = RegExp(r'\n[ \t]*\n');

  /// Tokenizes [text] (assumed already line-ending-normalized) into words.
  /// Returns an empty list for empty/whitespace-only input.
  List<FastToken> tokenize({
    required String bookId,
    required String text,
    int chapterIndex = 0,
  }) {
    if (text.trim().isEmpty) return const <FastToken>[];

    final tokens = <FastToken>[];
    var paragraphIndex = 0;
    var tokenIndex = 0;
    int? prevEnd;

    for (final match in _word.allMatches(text)) {
      if (prevEnd != null) {
        final gap = text.substring(prevEnd, match.start);
        if (_blankLine.hasMatch(gap)) paragraphIndex++;
      }
      final raw = match.group(0)!;
      tokens.add(
        FastToken(
          bookId: bookId,
          chapterIndex: chapterIndex,
          paragraphIndex: paragraphIndex,
          tokenIndex: tokenIndex,
          rawText: raw,
          normalizedText: raw.toLowerCase(),
          startOffset: match.start,
          endOffset: match.end,
        ),
      );
      tokenIndex++;
      prevEnd = match.end;
    }

    return tokens;
  }
}
