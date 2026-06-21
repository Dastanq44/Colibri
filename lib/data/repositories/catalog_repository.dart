import '../../core/result/result.dart';

/// Boundary for catalog discovery. Implemented in Phase 5 on top of Supabase
/// Postgres (full-text search + filters).
abstract interface class CatalogRepository {
  Future<Result<void>> searchBooks({required String query, int page = 0});

  Future<Result<void>> getBookDetails(String bookId);

  Future<Result<void>> getBooksByCategory(String categoryId);

  Future<Result<void>> getBooksByAuthor(String authorId);
}
