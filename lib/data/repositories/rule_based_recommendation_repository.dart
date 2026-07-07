import '../../core/result/result.dart';
import '../../features/catalog/domain/catalog_book.dart';
import '../../features/library/domain/library_book.dart';
import '../../features/recommendations/domain/recommendation_rail.dart';
import '../../shared/models/bookshelf_status.dart';
import 'catalog_repository.dart';
import 'library_repository.dart';
import 'recommendation_repository.dart';

/// Rule-based recommendations (Phase 14, no ML): composed from the catalog
/// and the user's local library. Rail assembly itself is pure
/// ([buildHomeRails]) so the rules are unit-testable without a backend.
class RuleBasedRecommendationRepository implements RecommendationRepository {
  RuleBasedRecommendationRepository({
    required CatalogRepository catalog,
    required LibraryRepository library,
  })  : _catalog = catalog,
        _library = library;

  /// One catalog page is plenty for rail assembly at MVP catalog sizes.
  static const int _catalogSample = 100;

  final CatalogRepository _catalog;
  final LibraryRepository _library;

  @override
  Future<Result<List<RecommendationRail>>> getHomeRecommendationRails() async {
    final catalogResult =
        await _catalog.searchBooks(pageSize: _catalogSample);
    if (catalogResult is Err) {
      return Err((catalogResult as Err).failure);
    }
    final localAuthors = switch (await _library.getMyBooks()) {
      Ok(value: final books) =>
        books.map((b) => b.authorDisplay).where((a) => a.isNotEmpty).toSet(),
      Err() => const <String>{},
    };
    return Ok(buildHomeRails(
      catalog: (catalogResult as Ok<List<CatalogBook>>).value,
      localAuthors: localAuthors,
    ));
  }

  @override
  Future<Result<List<CatalogBook>>> getSimilarBooks(String bookId) async {
    switch (await _catalog.getBookDetails(bookId)) {
      case Err(failure: final f):
        return Err(f);
      case Ok(value: final book):
        if (book == null) return const Ok(<CatalogBook>[]);
        final all = await _catalog.searchBooks(pageSize: _catalogSample);
        return switch (all) {
          Ok(value: final catalog) => Ok(
              buildHomeRails(
                catalog: catalog.where((b) => b.id != bookId).toList(),
                localAuthors: {book.authorDisplay},
              )
                  .where(
                      (rail) => rail.reason == RecommendationReason.sameAuthor)
                  .expand((rail) => rail.books)
                  .toList(growable: false),
            ),
          Err(failure: final f) => Err(f),
        };
    }
  }

  @override
  Future<Result<List<CatalogBook>>> getGoodForFastMode() async {
    final all = await _catalog.searchBooks(pageSize: _catalogSample);
    return switch (all) {
      Ok(value: final catalog) => Ok(catalog
          .where((b) => b.isFastModeSupported)
          .toList(growable: false)),
      Err(failure: final f) => Err(f),
    };
  }

  @override
  Future<Result<List<LibraryBook>>> getReturnToAbandoned() async {
    return switch (await _library.getMyBooks()) {
      Ok(value: final books) => Ok(books
          .where((b) => b.status == BookShelfStatus.abandoned)
          .toList(growable: false)),
      Err(failure: final f) => Err(f),
    };
  }
}
