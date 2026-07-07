import '../../core/result/result.dart';
import '../../features/catalog/domain/catalog_book.dart';

/// Boundary for catalog discovery (Phase 5), backed by Supabase Postgres.
abstract interface class CatalogRepository {
  /// Lists catalog books, filtered by [query] (title substring) when
  /// non-empty. [page] is zero-based with [pageSize] rows per page.
  Future<Result<List<CatalogBook>>> searchBooks({
    String query = '',
    int page = 0,
    int pageSize = 30,
  });

  /// A single catalog book, or `Ok(null)` when it does not exist.
  Future<Result<CatalogBook?>> getBookDetails(String bookId);

  Future<Result<List<CatalogBook>>> getBooksByCategory(String categoryId);

  Future<Result<List<CatalogBook>>> getBooksByAuthor(String authorId);

  /// Adds a catalog book to the signed-in user's cloud bookshelf as
  /// `want_to_read`. MVP: catalog books have no downloadable file yet, so
  /// the shelf entry is a marker, not a readable local book.
  Future<Result<void>> addToShelf(String bookId);
}
