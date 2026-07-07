/// Local reading statistics for the profile screen (TASK-0304).
class ReadingStats {
  const ReadingStats({
    required this.booksRead,
    required this.currentBooks,
    this.avgWpm,
  });

  /// Bookshelf entries marked finished.
  final int booksRead;

  /// Bookshelf entries currently being read.
  final int currentBooks;

  /// Average measured WPM across reading sessions; null until sessions are
  /// recorded (session tracking lands with analytics instrumentation).
  final int? avgWpm;
}
