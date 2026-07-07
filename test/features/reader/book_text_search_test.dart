import 'package:colibri/features/reader/domain/book_text_search.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('finds case-insensitive matches with offsets', () {
    const text = 'The Cat sat. Another cat ran. CAT!';
    final matches = searchBookText(text, 'cat').matches;
    expect(matches, hasLength(3));
    expect(matches[0].offset, 4);
    expect(matches[1].offset, 21);
    expect(matches[2].offset, 30);
  });

  test('handles Cyrillic case folding', () {
    const text = 'Война и мир. ВОЙНА закончилась. война';
    expect(searchBookText(text, 'Война').matches, hasLength(3));
  });

  test('matches phrases across line wraps (hard-wrapped TXT/EPUB)', () {
    const text = 'It was the best of times, it was the\nworst of times, '
        'it was the age of\nwisdom.';
    expect(searchBookText(text, 'the worst').matches, hasLength(1));
    expect(searchBookText(text, 'age of wisdom').matches, hasLength(1));
    // The reported offset points into the ORIGINAL text.
    final match = searchBookText(text, 'worst of').matches.single;
    expect(text.substring(match.offset, match.offset + 5), 'worst');
  });

  test('matches across multi-whitespace runs and normalizes query spaces',
      () {
    const text = 'chapter one\n\n  begins here';
    expect(searchBookText(text, 'one begins').matches, hasLength(1));
    expect(searchBookText(text, 'one   begins').matches, hasLength(1));
  });

  test('empty and whitespace queries return nothing', () {
    expect(searchBookText('some text', '').matches, isEmpty);
    expect(searchBookText('some text', '   ').matches, isEmpty);
    expect(searchBookText('', 'x').matches, isEmpty);
  });

  test('caps the results and reports truncation', () {
    final text = List.filled(500, 'word').join(' ');
    final result = searchBookText(text, 'word', maxResults: 100);
    expect(result.matches, hasLength(100));
    expect(result.truncated, isTrue);

    final exact = searchBookText(
      List.filled(100, 'word').join(' '),
      'word',
      maxResults: 100,
    );
    expect(exact.matches, hasLength(100));
    expect(exact.truncated, isFalse); // no 101st match -> not truncated
  });

  test('snippets are single-line, trimmed, and ellipsized inside the text',
      () {
    final text = 'start ${'a' * 100}\n\n  needle  \n${'b' * 100} end';
    final match = searchBookText(text, 'needle').matches.single;
    expect(match.snippet, startsWith('…'));
    expect(match.snippet, endsWith('…'));
    expect(match.snippet.contains('\n'), isFalse);
    expect(match.snippet, contains('needle'));
  });

  test('a match at the very start/end has no leading/trailing ellipsis', () {
    final head = searchBookText('needle in the middle', 'needle');
    expect(head.matches.single.snippet, isNot(startsWith('…')));

    final tail = searchBookText('the middle then needle', 'needle');
    expect(tail.matches.single.snippet, isNot(endsWith('…')));
  });

  test('snippet never splits a surrogate pair at the context boundary', () {
    // Position an emoji so the default 40-unit window would cut its pair.
    for (var pad = 35; pad <= 45; pad++) {
      final text = '😀${'x' * pad}needle${'y' * pad}😀';
      final match = searchBookText(text, 'needle').matches.single;
      for (final unit in match.snippet.codeUnits) {
        final isHigh = unit >= 0xD800 && unit <= 0xDBFF;
        final isLow = unit >= 0xDC00 && unit <= 0xDFFF;
        if (isHigh || isLow) {
          final units = match.snippet.codeUnits;
          final i = units.indexOf(unit);
          // Every surrogate must be part of a complete pair.
          final paired = (isHigh &&
                  i + 1 < units.length &&
                  units[i + 1] >= 0xDC00 &&
                  units[i + 1] <= 0xDFFF) ||
              (isLow && i > 0 && units[i - 1] >= 0xD800 && units[i - 1] <= 0xDBFF);
          expect(paired, isTrue,
              reason: 'unpaired surrogate at pad=$pad in "${match.snippet}"');
        }
      }
    }
  });

  test('percent grows with position', () {
    const text = 'aaa bbb ccc ddd needle';
    final match = searchBookText(text, 'needle').matches.single;
    expect(match.percent, greaterThan(50));
    expect(match.percent, lessThanOrEqualTo(100));
  });

  test('overlapping occurrences advance past each match', () {
    final matches = searchBookText('aaaa', 'aa').matches;
    expect(matches, hasLength(2)); // offsets 0 and 2, not 0/1/2
    expect(matches[0].offset, 0);
    expect(matches[1].offset, 2);
  });
}
