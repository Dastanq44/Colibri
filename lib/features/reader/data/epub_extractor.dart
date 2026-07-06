import 'dart:convert';

import 'package:archive/archive.dart';
import 'package:html/dom.dart' as dom;
import 'package:html/parser.dart' as html_parser;
import 'package:path/path.dart' as p;
import 'package:xml/xml.dart';

import '../domain/reader_chapter.dart';

/// Result of extracting readable text from an EPUB.
class EpubExtractionResult {
  const EpubExtractionResult({
    required this.chapters,
    this.title,
    this.author,
    this.language,
  });

  final List<ReaderChapter> chapters;
  final String? title;
  final String? author;
  final String? language;
}

/// Minimal EPUB → text extractor: ZIP → `container.xml` → OPF manifest/spine →
/// XHTML body text, preserving chapter order. Not a visual renderer.
///
/// Returns `null` on malformed/unparseable EPUBs (caller maps to a failure).
/// An empty `chapters` list means "opened, but no readable text".
class EpubExtractor {
  const EpubExtractor();

  static const Set<String> _blockTags = <String>{
    'p', 'div', 'br', 'li', 'section', 'article', 'blockquote', 'tr',
    'h1', 'h2', 'h3', 'h4', 'h5', 'h6',
  };

  EpubExtractionResult? extract(List<int> bytes) {
    try {
      final archive = ZipDecoder().decodeBytes(bytes);

      final containerXml = _readText(archive, 'META-INF/container.xml');
      if (containerXml == null) return null;
      final opfPath = _opfPath(containerXml);
      if (opfPath == null) return null;
      final opfText = _readText(archive, opfPath);
      if (opfText == null) return null;

      final opf = XmlDocument.parse(opfText);
      final baseDir = p.url.dirname(opfPath);

      final manifest = <String, String>{};
      for (final el in opf.descendants.whereType<XmlElement>()) {
        if (el.name.local == 'item') {
          final id = el.getAttribute('id');
          final href = el.getAttribute('href');
          if (id != null && href != null) manifest[id] = href;
        }
      }

      final chapters = <ReaderChapter>[];
      for (final el in opf.descendants.whereType<XmlElement>()) {
        if (el.name.local != 'itemref') continue;
        final idref = el.getAttribute('idref');
        if (idref == null) continue;
        final href = manifest[idref];
        if (href == null) continue;
        final html = _chapterHtml(archive, baseDir, href);
        if (html == null) continue;
        final text = _htmlToText(html);
        if (text.trim().isEmpty) continue;
        chapters.add(
          ReaderChapter(
            index: chapters.length,
            title: 'Chapter ${chapters.length + 1}',
            text: text,
          ),
        );
      }

      return EpubExtractionResult(
        chapters: chapters,
        title: _metaText(opf, 'title'),
        author: _metaText(opf, 'creator'),
        language: _metaText(opf, 'language'),
      );
    } catch (_) {
      return null;
    }
  }

  String? _opfPath(String containerXml) {
    final doc = XmlDocument.parse(containerXml);
    for (final el in doc.descendants.whereType<XmlElement>()) {
      if (el.name.local == 'rootfile') {
        final path = el.getAttribute('full-path');
        if (path != null && path.isNotEmpty) return path;
      }
    }
    return null;
  }

  String? _metaText(XmlDocument opf, String local) {
    for (final el in opf.descendants.whereType<XmlElement>()) {
      if (el.name.local == local) {
        final text = el.innerText.trim();
        if (text.isNotEmpty) return text;
      }
    }
    return null;
  }

  /// Manifest hrefs are URIs: strip any fragment and percent-decode before
  /// resolving against the OPF directory ("Chapter%201.xhtml" → zip entry
  /// "Chapter 1.xhtml"). Falls back to the raw href for archives whose entry
  /// names are stored still-encoded.
  String? _chapterHtml(Archive archive, String baseDir, String href) {
    final hash = href.indexOf('#');
    final raw = hash >= 0 ? href.substring(0, hash) : href;
    String decoded;
    try {
      decoded = Uri.decodeFull(raw);
    } on FormatException {
      decoded = raw;
    } on ArgumentError {
      // Uri.decodeFull throws ArgumentError on invalid percent-encodings.
      decoded = raw;
    }
    final html =
        _readText(archive, p.url.normalize(p.url.join(baseDir, decoded)));
    if (html != null || decoded == raw) return html;
    return _readText(archive, p.url.normalize(p.url.join(baseDir, raw)));
  }

  String? _readText(Archive archive, String path) {
    ArchiveFile? found;
    for (final file in archive.files) {
      if (file.name == path) {
        found = file;
        break;
      }
    }
    if (found == null) {
      final lower = path.toLowerCase();
      for (final file in archive.files) {
        if (file.name.toLowerCase() == lower) {
          found = file;
          break;
        }
      }
    }
    if (found == null || !found.isFile) return null;
    final content = found.content;
    if (content is List<int>) return _decodeBytes(content);
    return null;
  }

  /// Decodes chapter/OPF bytes: BOM first, then the XML declaration's
  /// `encoding` attribute, then lenient UTF-8 as a last resort.
  String _decodeBytes(List<int> bytes) {
    if (bytes.length >= 3 &&
        bytes[0] == 0xEF &&
        bytes[1] == 0xBB &&
        bytes[2] == 0xBF) {
      return utf8.decode(bytes.sublist(3), allowMalformed: true);
    }
    if (bytes.length >= 2 && bytes[0] == 0xFF && bytes[1] == 0xFE) {
      return _decodeUtf16(bytes, 2, littleEndian: true);
    }
    if (bytes.length >= 2 && bytes[0] == 0xFE && bytes[1] == 0xFF) {
      return _decodeUtf16(bytes, 2, littleEndian: false);
    }
    switch (_declaredEncoding(bytes)) {
      case 'utf-16le':
        return _decodeUtf16(bytes, 0, littleEndian: true);
      case 'utf-16be':
        return _decodeUtf16(bytes, 0, littleEndian: false);
      case 'utf-16':
        // No BOM: sniff byte order from the leading '<' of the declaration.
        return _decodeUtf16(bytes, 0, littleEndian: bytes[0] != 0x00);
      case 'windows-1251':
      case 'cp1251':
        return _decodeWindows1251(bytes);
      case 'iso-8859-1':
      case 'latin1':
      case 'latin-1':
        return latin1.decode(bytes);
    }
    return utf8.decode(bytes, allowMalformed: true);
  }

  /// Reads the `encoding` attribute of an `<?xml ...?>` declaration from the
  /// first bytes, treated as ASCII-compatible. NUL bytes are skipped so
  /// BOM-less UTF-16 declarations are still readable.
  String? _declaredEncoding(List<int> bytes) {
    final limit = bytes.length < 1024 ? bytes.length : 1024;
    final head = StringBuffer();
    for (var i = 0; i < limit; i++) {
      final b = bytes[i];
      if (b == 0x00) continue;
      head.writeCharCode(b < 0x80 ? b : 0x3F);
    }
    // Anchored: an XML declaration is only valid at the document start.
    // Matching anywhere would let declaration-looking strings in comments or
    // CDATA mis-decode an otherwise plain UTF-8 chapter.
    final decl =
        RegExp(r'^\s*<\?xml[^>]*\?>').firstMatch(head.toString());
    if (decl == null) return null;
    final enc = RegExp('encoding\\s*=\\s*["\']([^"\']+)["\']',
            caseSensitive: false)
        .firstMatch(decl.group(0)!);
    return enc?.group(1)?.trim().toLowerCase();
  }

  String _decodeUtf16(List<int> bytes, int start, {required bool littleEndian}) {
    final units = <int>[];
    for (var i = start; i + 1 < bytes.length; i += 2) {
      units.add(littleEndian
          ? bytes[i] | (bytes[i + 1] << 8)
          : (bytes[i] << 8) | bytes[i + 1]);
    }
    return String.fromCharCodes(units);
  }

  String _decodeWindows1251(List<int> bytes) {
    final units = List<int>.generate(
      bytes.length,
      (i) {
        final b = bytes[i] & 0xFF;
        return b < 0x80 ? b : _cp1251HighBytes[b - 0x80];
      },
    );
    return String.fromCharCodes(units);
  }

  /// windows-1251 high bytes 0x80–0xFF → Unicode code points.
  static const List<int> _cp1251HighBytes = <int>[
    0x0402, 0x0403, 0x201A, 0x0453, 0x201E, 0x2026, 0x2020, 0x2021, // 0x80
    0x20AC, 0x2030, 0x0409, 0x2039, 0x040A, 0x040C, 0x040B, 0x040F, // 0x88
    0x0452, 0x2018, 0x2019, 0x201C, 0x201D, 0x2022, 0x2013, 0x2014, // 0x90
    0x0098, 0x2122, 0x0459, 0x203A, 0x045A, 0x045C, 0x045B, 0x045F, // 0x98
    0x00A0, 0x040E, 0x045E, 0x0408, 0x00A4, 0x0490, 0x00A6, 0x00A7, // 0xA0
    0x0401, 0x00A9, 0x0404, 0x00AB, 0x00AC, 0x00AD, 0x00AE, 0x0407, // 0xA8
    0x00B0, 0x00B1, 0x0406, 0x0456, 0x0491, 0x00B5, 0x00B6, 0x00B7, // 0xB0
    0x0451, 0x2116, 0x0454, 0x00BB, 0x0458, 0x0405, 0x0455, 0x0457, // 0xB8
    0x0410, 0x0411, 0x0412, 0x0413, 0x0414, 0x0415, 0x0416, 0x0417, // 0xC0
    0x0418, 0x0419, 0x041A, 0x041B, 0x041C, 0x041D, 0x041E, 0x041F, // 0xC8
    0x0420, 0x0421, 0x0422, 0x0423, 0x0424, 0x0425, 0x0426, 0x0427, // 0xD0
    0x0428, 0x0429, 0x042A, 0x042B, 0x042C, 0x042D, 0x042E, 0x042F, // 0xD8
    0x0430, 0x0431, 0x0432, 0x0433, 0x0434, 0x0435, 0x0436, 0x0437, // 0xE0
    0x0438, 0x0439, 0x043A, 0x043B, 0x043C, 0x043D, 0x043E, 0x043F, // 0xE8
    0x0440, 0x0441, 0x0442, 0x0443, 0x0444, 0x0445, 0x0446, 0x0447, // 0xF0
    0x0448, 0x0449, 0x044A, 0x044B, 0x044C, 0x044D, 0x044E, 0x044F, // 0xF8
  ];

  String _htmlToText(String html) {
    final document = html_parser.parse(html);
    final body = document.body;
    if (body == null) return '';
    for (final el in body.querySelectorAll('script, style')) {
      el.remove();
    }
    final buffer = StringBuffer();
    _walk(body, buffer);

    var text = buffer.toString().replaceAll(RegExp(r'[ \t]+'), ' ');
    text = text.split('\n').map((line) => line.trim()).join('\n');
    text = text.replaceAll(RegExp(r'\n{3,}'), '\n\n');
    return text.trim();
  }

  void _walk(dom.Node node, StringBuffer buffer) {
    for (final child in node.nodes) {
      if (child is dom.Text) {
        buffer.write(child.text);
      } else if (child is dom.Element) {
        final tag = child.localName;
        if (tag == 'br') {
          buffer.write('\n');
          continue;
        }
        final isBlock = _blockTags.contains(tag);
        if (isBlock) buffer.write('\n');
        _walk(child, buffer);
        if (isBlock) buffer.write('\n');
      }
    }
  }
}
