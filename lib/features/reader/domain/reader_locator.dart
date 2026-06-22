/// A persisted reading position. For TXT this is a character offset; richer
/// formats add chapter/paragraph/token detail. [percent] is 0–100.
class ReaderLocator {
  const ReaderLocator({
    required this.locatorType,
    required this.locatorValue,
    required this.percent,
    this.chapterIndex,
    this.pageNumber,
    this.paragraphIndex,
    this.tokenIndex,
  });

  final String locatorType;
  final String locatorValue;
  final int? chapterIndex;
  final int? pageNumber;
  final int? paragraphIndex;
  final int? tokenIndex;
  final double percent;
}
