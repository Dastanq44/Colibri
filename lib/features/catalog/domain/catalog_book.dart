/// A catalog entry from Supabase (public, seeded metadata — not a local
/// file). Reading a catalog book requires a file pipeline that is post-MVP;
/// in MVP catalog books are discover + add-to-shelf only.
class CatalogBook {
  const CatalogBook({
    required this.id,
    required this.title,
    required this.authorDisplay,
    required this.format,
    this.subtitle,
    this.description,
    this.language,
    this.coverUrl,
    this.isFastModeSupported = false,
  });

  final String id;
  final String title;
  final String authorDisplay;
  final String format;
  final String? subtitle;
  final String? description;
  final String? language;
  final String? coverUrl;
  final bool isFastModeSupported;

  factory CatalogBook.fromRow(Map<String, dynamic> row) {
    final authorRows = (row['book_authors'] as List?) ?? const <dynamic>[];
    final authors = <String>[
      for (final entry in authorRows)
        if (((entry as Map)['authors'] as Map?)?['name'] != null)
          (entry['authors'] as Map)['name'] as String,
    ];
    return CatalogBook(
      id: row['id'] as String,
      title: (row['title'] as String?) ?? '',
      authorDisplay: authors.join(', '),
      format: (row['format'] as String?) ?? '',
      subtitle: row['subtitle'] as String?,
      description: row['description'] as String?,
      language: row['language'] as String?,
      coverUrl: row['cover_url'] as String?,
      isFastModeSupported: (row['is_fast_mode_supported'] as bool?) ?? false,
    );
  }
}
