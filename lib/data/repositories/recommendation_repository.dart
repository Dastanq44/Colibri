import '../../core/result/result.dart';
import '../../features/catalog/domain/catalog_book.dart';
import '../../features/library/domain/library_book.dart';
import '../../features/recommendations/domain/recommendation_rail.dart';

/// Boundary for rule-based (non-ML) recommendation rails (Phase 14). Every
/// rail carries an explainable [RecommendationReason].
abstract interface class RecommendationRepository {
  Future<Result<List<RecommendationRail>>> getHomeRecommendationRails();

  /// Catalog books by the same author(s) as [bookId].
  Future<Result<List<CatalogBook>>> getSimilarBooks(String bookId);

  Future<Result<List<CatalogBook>>> getGoodForFastMode();

  /// Local books the user abandoned — a "pick it back up" rail.
  Future<Result<List<LibraryBook>>> getReturnToAbandoned();
}
