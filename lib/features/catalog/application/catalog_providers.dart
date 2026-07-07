import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/errors/failures.dart';
import '../../../core/result/result.dart';
import '../../../data/remote/supabase_client_provider.dart';
import '../../../data/repositories/catalog_repository.dart';
import '../../../data/repositories/supabase_catalog_repository.dart';
import '../domain/catalog_book.dart';

final catalogRepositoryProvider = Provider<CatalogRepository>((ref) {
  return SupabaseCatalogRepository(ref.watch(supabaseClientProvider));
});

/// Paged catalog list state: the loaded books plus whether more pages may
/// exist (a full page implies "maybe more").
class CatalogListState {
  const CatalogListState({
    required this.books,
    required this.query,
    required this.loading,
    required this.canLoadMore,
    this.failure,
  });

  static const CatalogListState initial = CatalogListState(
    books: <CatalogBook>[],
    query: '',
    loading: true,
    canLoadMore: false,
  );

  final List<CatalogBook> books;
  final String query;
  final bool loading;
  final bool canLoadMore;
  final Failure? failure;

  CatalogListState copyWith({
    List<CatalogBook>? books,
    String? query,
    bool? loading,
    bool? canLoadMore,
    Failure? failure,
    bool clearFailure = false,
  }) =>
      CatalogListState(
        books: books ?? this.books,
        query: query ?? this.query,
        loading: loading ?? this.loading,
        canLoadMore: canLoadMore ?? this.canLoadMore,
        failure: clearFailure ? null : failure ?? this.failure,
      );
}

const int _pageSize = 30;

class CatalogListController extends AutoDisposeNotifier<CatalogListState> {
  int _page = 0;

  @override
  CatalogListState build() {
    Future.microtask(_loadFirstPage);
    return CatalogListState.initial;
  }

  Future<void> _loadFirstPage() => _load(reset: true);

  Future<void> search(String query) async {
    state = state.copyWith(query: query, clearFailure: true);
    await _load(reset: true);
  }

  Future<void> loadMore() async {
    if (state.loading || !state.canLoadMore) return;
    await _load(reset: false);
  }

  Future<void> retry() => _load(reset: true);

  Future<void> _load({required bool reset}) async {
    if (reset) _page = 0;
    final query = state.query;
    state = state.copyWith(loading: true, clearFailure: true);
    final result = await ref.read(catalogRepositoryProvider).searchBooks(
          query: query,
          page: _page,
          pageSize: _pageSize,
        );
    // A stale response for an outdated query must not clobber the new one.
    if (state.query != query) return;
    switch (result) {
      case Ok(value: final rows):
        _page += 1;
        state = state.copyWith(
          books: reset ? rows : <CatalogBook>[...state.books, ...rows],
          loading: false,
          canLoadMore: rows.length == _pageSize,
        );
      case Err(failure: final f):
        state = state.copyWith(loading: false, failure: f);
    }
  }
}

final catalogListProvider =
    NotifierProvider.autoDispose<CatalogListController, CatalogListState>(
  CatalogListController.new,
);

/// One catalog book's details for the detail screen.
final catalogBookProvider = FutureProvider.autoDispose
    .family<CatalogBook?, String>((ref, bookId) async {
  final result =
      await ref.watch(catalogRepositoryProvider).getBookDetails(bookId);
  return switch (result) {
    Ok(value: final book) => book,
    Err() => null,
  };
});
