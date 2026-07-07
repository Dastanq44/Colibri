import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/errors/failures.dart';
import '../../core/result/result.dart';
import '../../features/catalog/domain/catalog_book.dart';
import 'catalog_repository.dart';

const String _bookColumns = 'id, title, subtitle, description, language, '
    'format, cover_url, is_fast_mode_supported, book_authors(authors(name))';

/// Catalog reads against Supabase (public catalog data via RLS). Dev-safe:
/// every method returns a typed failure when no backend is configured.
///
/// Search uses a title ILIKE filter for MVP; Postgres full-text search can
/// replace it without touching callers.
class SupabaseCatalogRepository implements CatalogRepository {
  SupabaseCatalogRepository(this._client);

  final SupabaseClient? _client;

  @override
  Future<Result<List<CatalogBook>>> searchBooks({
    String query = '',
    int page = 0,
    int pageSize = 30,
  }) async {
    final client = _client;
    if (client == null) return const Err(BackendUnavailableFailure());
    try {
      var request = client.from('books').select(_bookColumns);
      final trimmed = query.trim();
      if (trimmed.isNotEmpty) {
        request = request.ilike('title', '%$trimmed%');
      }
      final from = page * pageSize;
      final rows = await request
          .order('title', ascending: true)
          .range(from, from + pageSize - 1);
      return Ok(rows.map(CatalogBook.fromRow).toList(growable: false));
    } catch (e) {
      return Err(NetworkFailure('Catalog unavailable: $e'));
    }
  }

  @override
  Future<Result<CatalogBook?>> getBookDetails(String bookId) async {
    final client = _client;
    if (client == null) return const Err(BackendUnavailableFailure());
    try {
      final row = await client
          .from('books')
          .select(_bookColumns)
          .eq('id', bookId)
          .maybeSingle();
      return Ok(row == null ? null : CatalogBook.fromRow(row));
    } catch (e) {
      return Err(NetworkFailure('Catalog unavailable: $e'));
    }
  }

  @override
  Future<Result<List<CatalogBook>>> getBooksByCategory(
    String categoryId,
  ) async {
    final client = _client;
    if (client == null) return const Err(BackendUnavailableFailure());
    try {
      final rows = await client
          .from('books')
          .select('$_bookColumns, book_categories!inner(category_id)')
          .eq('book_categories.category_id', categoryId)
          .order('title', ascending: true);
      return Ok(rows.map(CatalogBook.fromRow).toList(growable: false));
    } catch (e) {
      return Err(NetworkFailure('Catalog unavailable: $e'));
    }
  }

  @override
  Future<Result<List<CatalogBook>>> getBooksByAuthor(String authorId) async {
    final client = _client;
    if (client == null) return const Err(BackendUnavailableFailure());
    try {
      final rows = await client
          .from('books')
          .select('$_bookColumns, book_authors!inner(author_id)')
          .eq('book_authors.author_id', authorId)
          .order('title', ascending: true);
      return Ok(rows.map(CatalogBook.fromRow).toList(growable: false));
    } catch (e) {
      return Err(NetworkFailure('Catalog unavailable: $e'));
    }
  }

  @override
  Future<Result<void>> addToShelf(String bookId) async {
    final client = _client;
    if (client == null) return const Err(BackendUnavailableFailure());
    final userId = client.auth.currentUser?.id;
    if (userId == null) {
      return const Err(UnauthorizedFailure('Sign in to add books.'));
    }
    try {
      await client.from('user_bookshelf').upsert(
        <String, dynamic>{
          'user_id': userId,
          'book_id': bookId,
          'status': 'want_to_read',
        },
        onConflict: 'user_id,book_id',
      );
      return const Ok(null);
    } catch (e) {
      return Err(NetworkFailure('Could not add the book: $e'));
    }
  }
}
