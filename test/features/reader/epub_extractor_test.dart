import 'dart:convert';

import 'package:archive/archive.dart';
import 'package:colibri/features/reader/data/epub_extractor.dart';
import 'package:flutter_test/flutter_test.dart';

List<int> _zip(Map<String, String> files) {
  final archive = Archive();
  files.forEach((name, content) {
    final bytes = utf8.encode(content);
    archive.addFile(ArchiveFile(name, bytes.length, bytes));
  });
  return ZipEncoder().encode(archive)!;
}

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
}
