import 'dart:convert';
import 'dart:io';

import 'package:colibri/core/errors/failures.dart';
import 'package:colibri/core/result/result.dart';
import 'package:colibri/data/repositories/supabase_catalog_repository.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

void main() {
  test('no backend returns BackendUnavailableFailure', () async {
    final repo = SupabaseCatalogRepository(null);
    expect(((await repo.searchBooks()) as Err).failure,
        isA<BackendUnavailableFailure>());
    expect(((await repo.getBookDetails('x')) as Err).failure,
        isA<BackendUnavailableFailure>());
  });

  test('addToShelf requires a signed-in user', () async {
    final client = SupabaseClient('http://127.0.0.1:1', 'anon');
    addTearDown(() => client.dispose());
    final repo = SupabaseCatalogRepository(client);
    expect(((await repo.addToShelf('b')) as Err).failure,
        isA<UnauthorizedFailure>());
  });

  test('searchBooks parses rows with joined authors and sends paging',
      () async {
    final captured = <Uri>[];
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    addTearDown(() => server.close(force: true));
    server.listen((req) {
      captured.add(req.uri);
      req.response
        ..statusCode = 200
        ..headers.contentType = ContentType.json
        ..write(jsonEncode(<Map<String, dynamic>>[
          <String, dynamic>{
            'id': 'b1',
            'title': 'Война и мир',
            'format': 'epub',
            'language': 'ru',
            'is_fast_mode_supported': true,
            'book_authors': <Map<String, dynamic>>[
              <String, dynamic>{
                'authors': <String, dynamic>{'name': 'Лев Толстой'}
              },
            ],
          },
          <String, dynamic>{
            'id': 'b2',
            'title': 'No Author Book',
            'format': 'txt',
            'book_authors': <dynamic>[],
          },
        ]));
      req.response.close();
    });

    final client = SupabaseClient('http://127.0.0.1:${server.port}', 'anon');
    addTearDown(() => client.dispose());
    final repo = SupabaseCatalogRepository(client);

    final books =
        ((await repo.searchBooks(query: 'вой', page: 2, pageSize: 10)) as Ok)
            .value;
    expect(books, hasLength(2));
    // Merged results re-sort by title, so look books up by title.
    final tolstoy = books.firstWhere((b) => b.title == 'Война и мир');
    expect(tolstoy.authorDisplay, 'Лев Толстой');
    expect(tolstoy.isFastModeSupported, isTrue);
    final noAuthor = books.firstWhere((b) => b.title == 'No Author Book');
    expect(noAuthor.authorDisplay, isEmpty);

    // A query fans out to two legs: title ILIKE and author-name ILIKE (the
    // rows are merged and deduped by id — same 2 rows served to both legs).
    expect(captured, hasLength(2));
    final queries = captured.map((u) => u.query).toList();
    expect(queries.where((q) => q.contains('title=ilike')), hasLength(1));
    expect(
      queries.where(
          (q) => q.contains('book_authors.authors.name=ilike')),
      hasLength(1),
    );
    for (final q in queries) {
      expect(q, contains('order=title'));
    }
  });

  test('getBookDetails returns null for a missing book', () async {
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    addTearDown(() => server.close(force: true));
    server.listen((req) {
      req.response
        ..statusCode = 200
        ..headers.contentType = ContentType.json
        ..write('[]');
      req.response.close();
    });
    final client = SupabaseClient('http://127.0.0.1:${server.port}', 'anon');
    addTearDown(() => client.dispose());
    final repo = SupabaseCatalogRepository(client);

    expect(((await repo.getBookDetails('missing')) as Ok).value, isNull);
  });
}
