/// Supported book formats. [wire] is the value stored in the database and used
/// across the app (matches the `format` text column / Supabase check).
enum BookFormat {
  epub('epub'),
  txt('txt'),
  pdf('pdf');

  const BookFormat(this.wire);

  final String wire;

  /// Short uppercase badge label, e.g. "EPUB".
  String get badge => wire.toUpperCase();

  /// Resolves a format from a file extension (with or without a leading dot).
  /// Returns `null` for unsupported extensions.
  static BookFormat? fromExtension(String extension) {
    final e = extension.toLowerCase().replaceFirst('.', '').trim();
    return switch (e) {
      'epub' => BookFormat.epub,
      'txt' => BookFormat.txt,
      'pdf' => BookFormat.pdf,
      _ => null,
    };
  }

  /// Resolves a format from a stored wire value, defaulting to [txt].
  static BookFormat fromWire(String wire) =>
      BookFormat.values.firstWhere((f) => f.wire == wire, orElse: () => BookFormat.txt);
}
