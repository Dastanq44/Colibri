/// Live reading progress for the UI (current page within the paginated book).
class ReaderProgress {
  const ReaderProgress({
    required this.pageIndex,
    required this.pageCount,
    required this.percent,
  });

  final int pageIndex;
  final int pageCount;

  /// 0–100.
  final double percent;

  bool get hasPrevious => pageIndex > 0;
  bool get hasNext => pageIndex < pageCount - 1;
}
