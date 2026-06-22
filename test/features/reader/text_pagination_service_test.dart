import 'package:colibri/features/reader/data/text_pagination_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const service = TextPaginationService();

  test('short text produces a single page covering all of it', () {
    const text = 'Hello world.';
    final pages = service.paginate(text);

    expect(pages, hasLength(1));
    expect(pages.single.startOffset, 0);
    expect(pages.single.endOffset, text.length);
  });

  test('long text produces multiple pages with contiguous valid offsets', () {
    final text = List<String>.generate(
      60,
      (i) => 'Paragraph number $i with several words in it.',
    ).join('\n\n');

    final pages = service.paginate(text, targetChars: 200);

    expect(pages.length, greaterThan(1));
    expect(pages.first.startOffset, 0);
    expect(pages.last.endOffset, text.length);
    for (var i = 0; i < pages.length; i++) {
      expect(pages[i].startOffset, lessThan(pages[i].endOffset));
      if (i > 0) {
        expect(pages[i].startOffset, pages[i - 1].endOffset);
      }
    }
  });

  test('empty or whitespace-only text produces no pages', () {
    expect(service.paginate(''), isEmpty);
    expect(service.paginate('   \n\n  '), isEmpty);
  });
}
