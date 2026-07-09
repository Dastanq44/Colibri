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
      final trimmed = query.trim();
      final from = page * pageSize;

      if (trimmed.isEmpty) {
        final rows = await client
            .from('books')
            .select(_bookColumns)
            .order('title', ascending: true)
            .range(from, from + pageSize - 1);
        return Ok(rows.map(CatalogBook.fromRow).toList(growable: false));
      }

      // Match on title OR author name. PostgREST cannot OR across an embedded
      // relation, so run both filters in parallel and merge by id (title
      // matches first). Each leg is paged, so pagination keeps working; a
      // page may contain up to 2x pageSize rows when both legs are full.
      final byTitle = client
          .from('books')
          .select(_bookColumns)
          .ilike('title', '%$trimmed%')
          .order('title', ascending: true)
          .range(from, from + pageSize - 1);
      // Same columns, but with an inner join so the author filter applies.
      final byAuthor = client
          .from('books')
          .select(_bookColumns.replaceFirst(
            'book_authors(authors(name))',
            'book_authors!inner(authors!inner(name))',
          ))
          .ilike('book_authors.authors.name', '%$trimmed%')
          .order('title', ascending: true)
          .range(from, from + pageSize - 1);
      final results = await Future.wait(<Future<List<Map<String, dynamic>>>>[
        byTitle,
        byAuthor,
      ]);

      final seen = <String>{};
      final merged = <CatalogBook>[];
      for (final rows in results) {
        for (final row in rows) {
          final book = CatalogBook.fromRow(row);
          if (seen.add(book.id)) merged.add(book);
        }
      }
      merged.sort((a, b) => a.title.compareTo(b.title));
      return Ok(merged);
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
