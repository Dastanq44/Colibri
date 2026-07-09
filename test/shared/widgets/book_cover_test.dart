import 'dart:convert';
import 'dart:io';

import 'package:colibri/shared/widgets/book_cover.dart';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

// 1x1 PNG.
const String _pngB64 =
    'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR4nGP4z8DwHwAFAAH/q842iQAAAABJRU5ErkJggg==';

void main() {
  testWidgets('renders the cover image file when it exists', (tester) async {
    // Real file IO + image decode need runAsync (they never complete under
    // the fake-async test zone).
    final file = await tester.runAsync(() async {
      final dir = await Directory.systemTemp.createTemp('cover');
      addTearDown(() => dir.delete(recursive: true));
      final f = File('${dir.path}/c.png');
      await f.writeAsBytes(base64Decode(_pngB64));
      return f;
    });

    await tester.pumpWidget(MaterialApp(
      home: BookCover(coverPath: file!.path, width: 50, height: 70),
    ));
    await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 100)));
    await tester.pump();

    expect(find.byType(Image), findsOneWidget);
    expect(find.byIcon(Icons.menu_book_outlined), findsNothing);
  });

  testWidgets('missing path falls back to the grey book box', (tester) async {
    await tester.pumpWidget(const MaterialApp(
      home: BookCover(coverPath: null, width: 50, height: 70),
    ));
    expect(find.byIcon(Icons.menu_book_outlined), findsOneWidget);
  });

  testWidgets('unreadable file falls back to the grey book box',
      (tester) async {
    await tester.pumpWidget(const MaterialApp(
      home: BookCover(coverPath: '/nonexistent/x.png', width: 50, height: 70),
    ));
    await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 100)));
    await tester.pump();
    expect(find.byIcon(Icons.menu_book_outlined), findsOneWidget);
  });
}
