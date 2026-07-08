import 'package:colibri/features/reader/fast_mode/domain/fast_token.dart';
import 'package:colibri/features/reader/fast_mode/domain/natural_pause.dart';
import 'package:flutter_test/flutter_test.dart';

FastToken _tok(
  String raw, {
  int chapter = 0,
  int paragraph = 0,
}) =>
    FastToken(
      bookId: 'b',
      chapterIndex: chapter,
      paragraphIndex: paragraph,
      tokenIndex: 0,
      rawText: raw,
      normalizedText: raw.toLowerCase(),
      startOffset: 0,
      endOffset: raw.length,
    );

void main() {
  group('NaturalPause.multiplierFor', () {
    test('a plain word is unscaled', () {
      expect(NaturalPause.multiplierFor(_tok('quick'), _tok('brown')),
          NaturalPause.word);
    });

    test('comma / colon / semicolon / sentence weights', () {
      expect(NaturalPause.multiplierFor(_tok('however,'), _tok('the')),
          NaturalPause.comma);
      expect(NaturalPause.multiplierFor(_tok('this:'), _tok('that')),
          NaturalPause.clause);
      expect(NaturalPause.multiplierFor(_tok('wait;'), _tok('then')),
          NaturalPause.clause);
      expect(NaturalPause.multiplierFor(_tok('end.'), _tok('Next')),
          NaturalPause.sentence);
      expect(NaturalPause.multiplierFor(_tok('really?'), _tok('Yes')),
          NaturalPause.sentence);
      expect(NaturalPause.multiplierFor(_tok('stop!'), _tok('Now')),
          NaturalPause.sentence);
    });

    test('trailing quotes/brackets do not hide the real punctuation', () {
      expect(NaturalPause.multiplierFor(_tok('done."'), _tok('He')),
          NaturalPause.sentence);
      expect(NaturalPause.multiplierFor(_tok('"hello,"'), _tok('she')),
          NaturalPause.comma);
    });

    test('paragraph end outweighs a plain word', () {
      expect(
        NaturalPause.multiplierFor(
          _tok('word', paragraph: 0),
          _tok('next', paragraph: 1),
        ),
        NaturalPause.paragraph,
      );
    });

    test('paragraph end outweighs a sentence period', () {
      expect(
        NaturalPause.multiplierFor(
          _tok('end.', paragraph: 0),
          _tok('Next', paragraph: 1),
        ),
        NaturalPause.paragraph,
      );
    });

    test('chapter end is the strongest, and applies at end of book', () {
      expect(
        NaturalPause.multiplierFor(
          _tok('fin.', chapter: 0),
          _tok('Two', chapter: 1),
        ),
        NaturalPause.chapter,
      );
      expect(NaturalPause.multiplierFor(_tok('theEnd.'), null),
          NaturalPause.chapter);
    });

    test('null current token is unscaled', () {
      expect(NaturalPause.multiplierFor(null, _tok('x')), NaturalPause.word);
    });
  });
}
