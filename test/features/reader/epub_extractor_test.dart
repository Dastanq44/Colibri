import 'dart:convert';

import 'package:archive/archive.dart';
import 'package:colibri/features/reader/data/epub_extractor.dart';
import 'package:flutter_test/flutter_test.dart';

List<int> _zip(Map<String, String> files) =>
    _zipBytes(files.map((name, content) => MapEntry(name, utf8.encode(content))));

List<int> _zipBytes(Map<String, List<int>> files) {
  final archive = Archive();
  files.forEach((name, bytes) {
    archive.addFile(ArchiveFile(name, bytes.length, bytes));
  });
  return ZipEncoder().encode(archive)!;
}

/// Encodes [text] as windows-1251 (ASCII + basic Cyrillic, enough for tests).
List<int> _cp1251(String text) => text.codeUnits.map((c) {
      if (c < 0x80) return c;
      if (c >= 0x0410 && c <= 0x044F) return c - 0x350; // А..я
      if (c == 0x0401) return 0xA8; // Ё
      if (c == 0x0451) return 0xB8; // ё
      throw ArgumentError('char not supported by test cp1251 encoder: $c');
    }).toList();

List<int> _utf16le(String text, {bool bom = true}) {
  final out = <int>[if (bom) 0xFF, if (bom) 0xFE];
  for (final u in text.codeUnits) {
    out
      ..add(u & 0xFF)
      ..add((u >> 8) & 0xFF);
  }
  return out;
}

List<int> _utf16be(String text, {bool bom = true}) {
  final out = <int>[if (bom) 0xFE, if (bom) 0xFF];
  for (final u in text.codeUnits) {
    out
      ..add((u >> 8) & 0xFF)
      ..add(u & 0xFF);
  }
  return out;
}

/// OPF with a single-chapter manifest/spine using the given [href].
String _opfWithHref(String href) => '''
<?xml version="1.0"?>
<package xmlns="http://www.idpf.org/2007/opf" version="2.0">
  <manifest>
    <item id="c1" href="$href" media-type="application/xhtml+xml"/>
  </manifest>
  <spine>
    <itemref idref="c1"/>
  </spine>
</package>''';

const _containerXml = '''
<?xml version="1.0"?>
<container version="1.0" xmlns="urn:oasis:names:tc:opendocument:xmlns:container">
  <rootfiles>
    <rootfile full-path="OEBPS/content.opf" media-type="application/oebps-package+xml"/>
  </rootfiles>
</container>''';

String _opf({bool withMeta = true}) => '''
<?xml version="1.0"?>
<package xmlns="http://www.idpf.org/2007/opf" version="2.0">
  <metadata xmlns:dc="http://purl.org/dc/elements/1.1/">
    ${withMeta ? '<dc:title>My EPUB</dc:title><dc:creator>Jane Doe</dc:creator><dc:language>en</dc:language>' : ''}
  </metadata>
  <manifest>
    <item id="c1" href="chapter1.xhtml" media-type="application/xhtml+xml"/>
    <item id="c2" href="chapter2.xhtml" media-type="application/xhtml+xml"/>
  </manifest>
  <spine>
    <itemref idref="c1"/>
    <itemref idref="c2"/>
  </spine>
</package>''';

void main() {
  const extractor = EpubExtractor();

  test('extracts text, metadata and spine order from a simple EPUB', () {
    final bytes = _zip(<String, String>{
      'META-INF/container.xml': _containerXml,
      'OEBPS/content.opf': _opf(),
      'OEBPS/chapter1.xhtml':
          '<html><body><h1>One</h1><p>Hello world.</p></body></html>',
      'OEBPS/chapter2.xhtml':
          '<html><body><p>Second chapter text.</p></body></html>',
    });

    final result = extractor.extract(bytes);

    expect(result, isNotNull);
    expect(result!.title, 'My EPUB');
    expect(result.author, 'Jane Doe');
    expect(result.language, 'en');
    expect(result.chapters.length, 2);
    expect(result.chapters[0].index, 0);
    expect(result.chapters[0].text.contains('Hello world'), isTrue);
    expect(result.chapters[1].text.contains('Second chapter'), isTrue);
  });

  group('source line wrapping', () {
    String extract(String bodyHtml) {
      final bytes = _zip(<String, String>{
        'META-INF/container.xml': _containerXml,
        'OEBPS/content.opf': _opfWithHref('chapter1.xhtml'),
        'OEBPS/chapter1.xhtml': '<html><body>$bodyHtml</body></html>',
      });
      final result = extractor.extract(bytes);
      expect(result, isNotNull);
      expect(result!.chapters, isNotEmpty);
      return result.chapters.first.text;
    }

    test('hard-wrapped paragraph collapses to one flowing line', () {
      // A single <p> whose text is wrapped across source lines (as most EPUBs
      // ship) must not keep those newlines as hard breaks.
      final text = extract('<p>The quick brown fox jumped over the lazy dog\n'
          'and then continued on its way through the forest\n'
          'until it reached the river.</p>');
      expect(text, 'The quick brown fox jumped over the lazy dog and then '
          'continued on its way through the forest until it reached the '
          'river.');
      expect(text.contains('\n'), isFalse);
    });

    test('paragraph breaks survive as a blank line between paragraphs', () {
      final text = extract('<p>First paragraph line one\nline two.</p>'
          '<p>Second paragraph\nhere.</p>');
      expect(text, 'First paragraph line one line two.\n\n'
          'Second paragraph here.');
    });

    test('<br> stays a single line break inside a paragraph', () {
      final text = extract('<p>Line one<br/>Line two</p>');
      expect(text, 'Line one\nLine two');
    });

    test('leading source indentation is not rendered as text', () {
      final text =
          extract('<p>\n    Indented source,\n    still one line.\n</p>');
      expect(text, 'Indented source, still one line.');
    });

    test('<pre> keeps its significant newlines', () {
      final text = extract('<pre>line one\nline two\nline three</pre>');
      expect(text.contains('line one\nline two'), isTrue);
    });
  });

  test('metadata falls back to null when absent', () {
    final bytes = _zip(<String, String>{
      'META-INF/container.xml': _containerXml,
      'OEBPS/content.opf': _opf(withMeta: false),
      'OEBPS/chapter1.xhtml': '<html><body><p>Text.</p></body></html>',
      'OEBPS/chapter2.xhtml': '<html><body><p>More.</p></body></html>',
    });

    final result = extractor.extract(bytes);
    expect(result, isNotNull);
    expect(result!.title, isNull);
    expect(result.chapters, isNotEmpty);
  });

  test('an EPUB with no readable text yields empty chapters', () {
    final bytes = _zip(<String, String>{
      'META-INF/container.xml': _containerXml,
      'OEBPS/content.opf': _opf(),
      'OEBPS/chapter1.xhtml': '<html><body></body></html>',
      'OEBPS/chapter2.xhtml': '<html><body>   </body></html>',
    });

    final result = extractor.extract(bytes);
    expect(result, isNotNull);
    expect(result!.chapters, isEmpty);
  });

  test('malformed (non-zip) bytes return null', () {
    expect(extractor.extract(utf8.encode('this is not a zip')), isNull);
  });

  group('percent-encoded hrefs', () {
    test('href with %20 resolves to zip entry with a space', () {
      final bytes = _zip(<String, String>{
        'META-INF/container.xml': _containerXml,
        'OEBPS/content.opf': _opfWithHref('Chapter%201.xhtml'),
        'OEBPS/Chapter 1.xhtml':
            '<html><body><p>Space in name.</p></body></html>',
      });

      final result = extractor.extract(bytes);
      expect(result, isNotNull);
      expect(result!.chapters.length, 1);
      expect(result.chapters[0].text, contains('Space in name'));
    });

    test('percent-encoded non-ASCII href resolves to UTF-8 entry name', () {
      final bytes = _zip(<String, String>{
        'META-INF/container.xml': _containerXml,
        'OEBPS/content.opf':
            _opfWithHref('%D0%93%D0%BB%D0%B0%D0%B2%D0%B0.xhtml'), // Глава
        'OEBPS/Глава.xhtml': '<html><body><p>Кириллица.</p></body></html>',
      });

      final result = extractor.extract(bytes);
      expect(result, isNotNull);
      expect(result!.chapters.length, 1);
      expect(result.chapters[0].text, contains('Кириллица'));
    });

    test('falls back to the raw href when the entry is stored encoded', () {
      final bytes = _zip(<String, String>{
        'META-INF/container.xml': _containerXml,
        'OEBPS/content.opf': _opfWithHref('Chapter%201.xhtml'),
        'OEBPS/Chapter%201.xhtml':
            '<html><body><p>Still encoded.</p></body></html>',
      });

      final result = extractor.extract(bytes);
      expect(result, isNotNull);
      expect(result!.chapters.length, 1);
      expect(result.chapters[0].text, contains('Still encoded'));
    });

    test('invalid percent sequence falls back to the raw href', () {
      final bytes = _zip(<String, String>{
        'META-INF/container.xml': _containerXml,
        'OEBPS/content.opf': _opfWithHref('Bad%ZZname.xhtml'),
        'OEBPS/Bad%ZZname.xhtml':
            '<html><body><p>Raw survives.</p></body></html>',
      });

      final result = extractor.extract(bytes);
      expect(result, isNotNull);
      expect(result!.chapters.length, 1);
      expect(result.chapters[0].text, contains('Raw survives'));
    });

    test('fragment in href is stripped before lookup', () {
      final bytes = _zip(<String, String>{
        'META-INF/container.xml': _containerXml,
        'OEBPS/content.opf': _opfWithHref('chapter1.xhtml#section2'),
        'OEBPS/chapter1.xhtml':
            '<html><body><p>Fragment ignored.</p></body></html>',
      });

      final result = extractor.extract(bytes);
      expect(result, isNotNull);
      expect(result!.chapters.length, 1);
      expect(result.chapters[0].text, contains('Fragment ignored'));
    });
  });

  group('chapter encodings', () {
    List<int> epubWithChapterBytes(List<int> chapterBytes) =>
        _zipBytes(<String, List<int>>{
          'META-INF/container.xml': utf8.encode(_containerXml),
          'OEBPS/content.opf': utf8.encode(_opfWithHref('chapter1.xhtml')),
          'OEBPS/chapter1.xhtml': chapterBytes,
        });

    test('windows-1251 chapter with XML declaration decodes to Cyrillic', () {
      final bytes = epubWithChapterBytes(_cp1251(
        '<?xml version="1.0" encoding="windows-1251"?>'
        '<html><body><p>Привет, мир! Ёжик, ёлка.</p></body></html>',
      ));

      final result = extractor.extract(bytes);
      expect(result, isNotNull);
      expect(result!.chapters.length, 1);
      expect(result.chapters[0].text, contains('Привет, мир!'));
      expect(result.chapters[0].text, contains('Ёжик, ёлка.'));
      expect(result.chapters[0].text, isNot(contains('�')));
    });

    test('UTF-16LE chapter with BOM decodes correctly', () {
      final bytes = epubWithChapterBytes(_utf16le(
        '<?xml version="1.0" encoding="utf-16"?>'
        '<html><body><p>Привет UTF-16 🚀</p></body></html>',
      ));

      final result = extractor.extract(bytes);
      expect(result, isNotNull);
      expect(result!.chapters.length, 1);
      expect(result.chapters[0].text, contains('Привет UTF-16 🚀'));
    });

    test('UTF-16BE chapter with BOM decodes correctly', () {
      final bytes = epubWithChapterBytes(_utf16be(
        '<html><body><p>Big endian текст</p></body></html>',
      ));

      final result = extractor.extract(bytes);
      expect(result, isNotNull);
      expect(result!.chapters.length, 1);
      expect(result.chapters[0].text, contains('Big endian текст'));
    });

    test('BOM-less UTF-16LE chapter with XML declaration decodes', () {
      final bytes = epubWithChapterBytes(_utf16le(
        '<?xml version="1.0" encoding="utf-16le"?>'
        '<html><body><p>Без BOM</p></body></html>',
        bom: false,
      ));

      final result = extractor.extract(bytes);
      expect(result, isNotNull);
      expect(result!.chapters.length, 1);
      expect(result.chapters[0].text, contains('Без BOM'));
    });

    test('iso-8859-1 chapter with XML declaration decodes', () {
      final bytes = epubWithChapterBytes(latin1.encode(
        '<?xml version="1.0" encoding="ISO-8859-1"?>'
        '<html><body><p>Café niño</p></body></html>',
      ));

      final result = extractor.extract(bytes);
      expect(result, isNotNull);
      expect(result!.chapters.length, 1);
      expect(result.chapters[0].text, contains('Café niño'));
    });

    test('UTF-8 chapter with BOM decodes without a leading BOM char', () {
      final bytes = epubWithChapterBytes(<int>[
        0xEF, 0xBB, 0xBF,
        ...utf8.encode('<html><body><p>BOM UTF-8 текст</p></body></html>'),
      ]);

      final result = extractor.extract(bytes);
      expect(result, isNotNull);
      expect(result!.chapters.length, 1);
      expect(result.chapters[0].text, contains('BOM UTF-8 текст'));
      expect(result.chapters[0].text, isNot(contains('﻿')));
    });

    test('undeclared UTF-8 chapter still decodes (fallback path)', () {
      final bytes = epubWithChapterBytes(
        utf8.encode('<html><body><p>Обычный UTF-8</p></body></html>'),
      );

      final result = extractor.extract(bytes);
      expect(result, isNotNull);
      expect(result!.chapters.length, 1);
      expect(result.chapters[0].text, contains('Обычный UTF-8'));
    });
  });

  group('cover extraction', () {
    const png = <int>[0x89, 0x50, 0x4E, 0x47, 1, 2, 3, 4];

    List<int> epub(Map<String, Object> files) => _zipBytes(<String, List<int>>{
          'META-INF/container.xml': utf8.encode(_containerXml),
          for (final e in files.entries)
            'OEBPS/${e.key}': e.value is String
                ? utf8.encode(e.value as String)
                : (e.value as List<int>),
        });

    test('EPUB 3 properties="cover-image" wins', () {
      final bytes = epub(<String, Object>{
        'content.opf': """
<?xml version="1.0"?>
<package xmlns="http://www.idpf.org/2007/opf" version="3.0">
  <manifest>
    <item id="cimg" href="art.png" media-type="image/png" properties="cover-image"/>
    <item id="c1" href="chapter1.xhtml" media-type="application/xhtml+xml"/>
  </manifest>
  <spine><itemref idref="c1"/></spine>
</package>""",
        'chapter1.xhtml': '<html><body><p>Text.</p></body></html>',
        'art.png': png,
      });

      final cover = extractor.extractCover(bytes);
      expect(cover, isNotNull);
      expect(cover!.extension, 'png');
      expect(cover.bytes, png);
    });

    test('EPUB 2 meta name="cover" pointer resolves via the manifest', () {
      final bytes = epub(<String, Object>{
        'content.opf': """
<?xml version="1.0"?>
<package xmlns="http://www.idpf.org/2007/opf" version="2.0">
  <metadata><meta name="cover" content="cimg"/></metadata>
  <manifest>
    <item id="cimg" href="images/front.jpeg" media-type="image/jpeg"/>
    <item id="c1" href="chapter1.xhtml" media-type="application/xhtml+xml"/>
  </manifest>
  <spine><itemref idref="c1"/></spine>
</package>""",
        'chapter1.xhtml': '<html><body><p>Text.</p></body></html>',
        'images/front.jpeg': png,
      });

      final cover = extractor.extractCover(bytes);
      expect(cover, isNotNull);
      expect(cover!.extension, 'jpg');
    });

    test('cover-named image item is the fallback', () {
      final bytes = epub(<String, Object>{
        'content.opf': _opfWithHref('chapter1.xhtml').replaceFirst(
          '<manifest>',
          '<manifest><item id="x" href="cover.png" media-type="image/png"/>',
        ),
        'chapter1.xhtml': '<html><body><p>Text.</p></body></html>',
        'cover.png': png,
      });

      expect(extractor.extractCover(bytes), isNotNull);
    });

    test('no cover -> null (and malformed zip -> null)', () {
      final bytes = epub(<String, Object>{
        'content.opf': _opfWithHref('chapter1.xhtml'),
        'chapter1.xhtml': '<html><body><p>Text.</p></body></html>',
      });
      expect(extractor.extractCover(bytes), isNull);
      expect(extractor.extractCover(utf8.encode('not a zip')), isNull);
    });
  });
}
