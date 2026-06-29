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
        final path = p.url.normalize(p.url.join(baseDir, href));
        final html = _readText(archive, path);
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
    if (content is List<int>) return utf8.decode(content, allowMalformed: true);
    return null;
  }

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
