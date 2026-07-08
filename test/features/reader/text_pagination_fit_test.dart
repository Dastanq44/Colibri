import 'package:colibri/features/reader/data/text_pagination_service.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const service = TextPaginationService();
  const style = TextStyle(fontSize: 20, height: 1.4);
  const maxWidth = 300.0;
  const maxHeight = 260.0;

  double heightOf(String text) {
    final painter = TextPainter(
      text: TextSpan(text: text, style: style),
      textDirection: TextDirection.ltr,
      maxLines: null,
    )..layout(maxWidth: maxWidth);
    return painter.height;
  }

  testWidgets('every page fits the viewport height', (tester) async {
    final text = List<String>.generate(600, (i) => 'word$i').join(' ');
    final pages = service.paginateToFit(
      text,
      maxWidth: maxWidth,
      maxHeight: maxHeight,
      style: style,
    );

    expect(pages.length, greaterThan(1)); // long text spans many pages
    for (final page in pages) {
      expect(heightOf(page.text), lessThanOrEqualTo(maxHeight + 0.5),
          reason: 'page ${page.pageIndex} overflows');
    }
  });

  testWidgets('offsets are contiguous and cover the whole text',
      (tester) async {
    final text = List<String>.generate(300, (i) => 'token$i').join(' ');
    final pages = service.paginateToFit(
      text,
      maxWidth: maxWidth,
      maxHeight: maxHeight,
      style: style,
    );

    expect(pages.first.startOffset, 0);
    expect(pages.last.endOffset, text.length);
    for (var i = 0; i < pages.length; i++) {
      expect(pages[i].endOffset, greaterThan(pages[i].startOffset));
      if (i > 0) expect(pages[i].startOffset, pages[i - 1].endOffset);
    }
    // Concatenating page texts reproduces the source exactly.
    expect(pages.map((p) => p.text).join(), text);
  });

  testWidgets('paragraph breaks are preferred; words are not split',
      (tester) async {
    final para = List<String>.filled(40, 'lorem').join(' ');
    final text = List<String>.filled(20, para).join('\n\n');
    final pages = service.paginateToFit(
      text,
      maxWidth: maxWidth,
      maxHeight: maxHeight,
      style: style,
    );
    for (final page in pages) {
      // A page never starts or ends in the middle of the word "lorem".
      expect(page.text.trimRight().endsWith('m') ||
          page.text.trimRight().isEmpty ||
          page.endOffset == text.length ||
          page.text.endsWith('\n'),
          isTrue);
    }
  });

  testWidgets('degenerate sizes yield no pages (no crash)', (tester) async {
    expect(service.paginateToFit('hello',
        maxWidth: 0, maxHeight: 100, style: style), isEmpty);
    expect(service.paginateToFit('',
        maxWidth: 100, maxHeight: 100, style: style), isEmpty);
  });
}
