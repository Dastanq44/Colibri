/// A single word token for fast (RSVP-style) reading, with offsets that map
/// back to the source text so fast-mode position stays continuous with the
/// normal reader.
class FastToken {
  const FastToken({
    required this.bookId,
    required this.chapterIndex,
    required this.paragraphIndex,
    required this.tokenIndex,
    required this.rawText,
    required this.normalizedText,
    required this.startOffset,
    required this.endOffset,
  });

  final String bookId;
  final int chapterIndex;
  final int paragraphIndex;
  final int tokenIndex;

  /// Word as it appears (punctuation preserved), e.g. `world!`.
  final String rawText;

  /// Lower-cased form for matching/metrics.
  final String normalizedText;

  /// Inclusive start / exclusive end character offsets in the source text.
  final int startOffset;
  final int endOffset;
}
