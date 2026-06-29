import 'package:colibri/features/reader/fast_mode/data/fast_mode_tokenizer.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const tokenizer = FastModeTokenizer();

  test('tokenizes English keeping punctuation attached', () {
    final tokens = tokenizer.tokenize(bookId: 'b1', text: 'Hello, world!');

    expect(tokens.map((t) => t.rawText).toList(), <String>['Hello,', 'world!']);
    expect(tokens[0].tokenIndex, 0);
    expect(tokens[1].tokenIndex, 1);
    expect(tokens[0].startOffset, 0);
    expect(tokens[0].endOffset, 6);
    expect(tokens[1].startOffset, 7);
  });

  test('tokenizes Cyrillic text', () {
    final tokens = tokenizer.tokenize(bookId: 'b1', text: 'Привет, мир!');
    expect(tokens.map((t) => t.rawText).toList(), <String>['Привет,', 'мир!']);
  });

  test('tracks paragraph index across blank lines', () {
    final tokens =
        tokenizer.tokenize(bookId: 'b1', text: 'one two\n\nthree four');
    expect(
      tokens.map((t) => t.paragraphIndex).toList(),
      <int>[0, 0, 1, 1],
    );
  });

  test('whitespace-only or empty text returns no tokens', () {
    expect(tokenizer.tokenize(bookId: 'b1', text: '   \n\n  '), isEmpty);
    expect(tokenizer.tokenize(bookId: 'b1', text: ''), isEmpty);
  });

  test('offsets map back to the source text', () {
    const text = 'alpha beta gamma';
    final tokens = tokenizer.tokenize(bookId: 'b1', text: text);
    for (final t in tokens) {
      expect(text.substring(t.startOffset, t.endOffset), t.rawText);
    }
  });
}
