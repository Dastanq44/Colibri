import 'package:colibri/features/catalog/domain/catalog_book.dart';
import 'package:colibri/features/recommendations/domain/recommendation_rail.dart';
import 'package:flutter_test/flutter_test.dart';

CatalogBook _book(String id,
        {String author = '', bool fast = false}) =>
    CatalogBook(
      id: id,
      title: 'Book $id',
      authorDisplay: author,
      format: 'epub',
      isFastModeSupported: fast,
    );

void main() {
  test('same-author rail matches case-insensitively across author lists', () {
    final rails = buildHomeRails(
      catalog: <CatalogBook>[
        _book('a', author: 'Лев Толстой'),
        _book('b', author: 'Jane Austen, Lewis Carroll'),
        _book('c', author: 'Someone Else'),
      ],
      localAuthors: {'лев толстой', 'LEWIS CARROLL'},
    );

    final sameAuthor = rails
        .firstWhere((r) => r.reason == RecommendationReason.sameAuthor);
    expect(sameAuthor.books.map((b) => b.id), containsAll(<String>['a', 'b']));
    expect(sameAuthor.books.map((b) => b.id), isNot(contains('c')));
  });

  test('fast-mode rail lists only flagged books', () {
    final rails = buildHomeRails(
      catalog: <CatalogBook>[
        _book('a', fast: true),
        _book('b'),
      ],
      localAuthors: const <String>{},
    );

    final fast = rails
        .firstWhere((r) => r.reason == RecommendationReason.goodForFastMode);
    expect(fast.books.map((b) => b.id), <String>['a']);
    // No author matches -> no same-author rail.
    expect(rails.any((r) => r.reason == RecommendationReason.sameAuthor),
        isFalse);
  });

  test('falls back to a plain catalog rail when no rule matches', () {
    final rails = buildHomeRails(
      catalog: <CatalogBook>[_book('a'), _book('b')],
      localAuthors: const <String>{},
    );
    expect(rails, hasLength(1));
    expect(rails.single.reason, RecommendationReason.fromCatalog);
    expect(rails.single.books, hasLength(2));
  });

  test('empty catalog yields no rails; rails are capped', () {
    expect(
      buildHomeRails(catalog: const <CatalogBook>[], localAuthors: const {}),
      isEmpty,
    );
    final rails = buildHomeRails(
      catalog: List<CatalogBook>.generate(30, (i) => _book('$i', fast: true)),
      localAuthors: const <String>{},
      railSize: 10,
    );
    final fast = rails
        .firstWhere((r) => r.reason == RecommendationReason.goodForFastMode);
    expect(fast.books, hasLength(10));
  });
}
