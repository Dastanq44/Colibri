import '../../catalog/domain/catalog_book.dart';

/// Why a rail is shown (plan TASK-1402: every recommendation is explainable).
enum RecommendationReason { sameAuthor, goodForFastMode, fromCatalog }

/// A titled row of recommended catalog books.
class RecommendationRail {
  const RecommendationRail({required this.reason, required this.books});

  final RecommendationReason reason;
  final List<CatalogBook> books;
}

/// Pure rail assembly from a catalog snapshot (rule-based, no ML):
/// - books by authors the user already reads,
/// - books flagged good for fast mode,
/// - a plain catalog rail as fallback so Home is never empty of rails.
/// Capped at [railSize] per rail.
List<RecommendationRail> buildHomeRails({
  required List<CatalogBook> catalog,
  required Set<String> localAuthors,
  int railSize = 10,
}) {
  if (catalog.isEmpty) return const <RecommendationRail>[];

  final normalizedLocal = localAuthors
      .expand((a) => a.split(','))
      .map((a) => a.trim().toLowerCase())
      .where((a) => a.isNotEmpty)
      .toSet();

  bool byKnownAuthor(CatalogBook book) => book.authorDisplay
      .split(',')
      .map((a) => a.trim().toLowerCase())
      .any(normalizedLocal.contains);

  final sameAuthor =
      catalog.where(byKnownAuthor).take(railSize).toList(growable: false);
  final fastMode = catalog
      .where((b) => b.isFastModeSupported)
      .take(railSize)
      .toList(growable: false);

  return <RecommendationRail>[
    if (sameAuthor.isNotEmpty)
      RecommendationRail(
          reason: RecommendationReason.sameAuthor, books: sameAuthor),
    if (fastMode.isNotEmpty)
      RecommendationRail(
          reason: RecommendationReason.goodForFastMode, books: fastMode),
    if (sameAuthor.isEmpty && fastMode.isEmpty)
      RecommendationRail(
        reason: RecommendationReason.fromCatalog,
        books: catalog.take(railSize).toList(growable: false),
      ),
  ];
}
