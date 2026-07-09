import 'package:colibri/core/services/app_paths.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  setUp(() => AppPaths.documentsOverride =
      '/var/mobile/Containers/Data/Application/NEW-UUID/Documents');

  test('re-bases an absolute path from an older container', () {
    expect(
      AppPaths.absolute(
          '/var/mobile/Containers/Data/Application/OLD-UUID/Documents/books/b1/book.epub'),
      '/var/mobile/Containers/Data/Application/NEW-UUID/Documents/books/b1/book.epub',
    );
  });

  test('a current-container path is unchanged by re-basing', () {
    const current =
        '/var/mobile/Containers/Data/Application/NEW-UUID/Documents/profile/avatar.jpg';
    expect(AppPaths.absolute(current), current);
  });

  test('joins a relative path onto Documents', () {
    expect(
      AppPaths.absolute('books/b2/cover.png'),
      '/var/mobile/Containers/Data/Application/NEW-UUID/Documents/books/b2/cover.png',
    );
  });

  test('non-Documents absolute paths pass through (tests, tmp)', () {
    expect(AppPaths.absolute('/tmp/foo/bar.epub'), '/tmp/foo/bar.epub');
  });

  test('null and empty resolve to null', () {
    expect(AppPaths.absolute(null), isNull);
    expect(AppPaths.absolute(''), isNull);
  });
}
