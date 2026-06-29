import 'package:colibri/core/result/result.dart';
import 'package:colibri/data/repositories/reader_repository.dart';
import 'package:colibri/features/reader/application/reader_controller.dart';
import 'package:colibri/features/reader/application/reader_providers.dart';
import 'package:colibri/features/reader/domain/reader_chapter.dart';
import 'package:colibri/features/reader/domain/reader_document.dart';
import 'package:colibri/features/reader/domain/reader_locator.dart';
import 'package:colibri/features/reader/domain/reader_mode.dart';
import 'package:colibri/features/reader/domain/reader_page.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

class _FakeReaderRepo implements ReaderRepository {
  _FakeReaderRepo(this._doc, this._saved);

  final ReaderDocument _doc;
  final ReaderLocator? _saved;
  ReaderLocator? lastSaved;

  @override
  Future<Result<ReaderDocument>> openBook(String bookId) async => Ok(_doc);

  @override
  Future<Result<ReaderLocator?>> getSavedLocator(String bookId) async =>
      Ok(_saved);

  @override
  Future<Result<void>> saveLocator(
    String bookId,
    ReaderLocator locator, {
    ReaderMode mode = ReaderMode.normal,
  }) async {
    lastSaved = locator;
    return const Ok(null);
  }
}

ReaderReady _ready(int pageIndex, int count) => ReaderReady(
      document: const ReaderDocument(
        bookId: 'b',
        title: 't',
        format: 'txt',
        chapters: <ReaderChapter>[],
      ),
      pages: List<ReaderPage>.generate(
        count,
        (i) => ReaderPage(
          pageIndex: i,
          text: 'p$i',
          startOffset: i * 10,
          endOffset: i * 10 + 10,
        ),
      ),
      pageIndex: pageIndex,
    );

Future<ReaderReady> _pumpReady(ProviderContainer c, String id) async {
  for (var i = 0; i < 100; i++) {
    final s = c.read(readerControllerProvider(id));
    if (s is ReaderReady) return s;
    await Future<void>.delayed(const Duration(milliseconds: 5));
  }
  throw StateError('reader never became ready');
}

ProviderContainer _container(ReaderLocator? saved) {
  final doc = ReaderDocument(
    bookId: 'b',
    title: 't',
    format: 'txt',
    chapters: <ReaderChapter>[
      ReaderChapter(
        index: 0,
        title: 't',
        text: List<String>.filled(2000, 'word').join(' '),
      ),
    ],
  );
  final c = ProviderContainer(
    overrides: <Override>[
      readerRepositoryProvider.overrideWithValue(_FakeReaderRepo(doc, saved)),
    ],
  );
  addTearDown(c.dispose);
  return c;
}

void main() {
  group('ReaderProgress percent', () {
    test('first / middle / last pages', () {
      expect(_ready(0, 3).progress.percent, 0);
      expect(_ready(1, 3).progress.percent, 50);
      expect(_ready(2, 3).progress.percent, 100);
    });

    test('single page is 100% with no next/previous', () {
      final p = _ready(0, 1).progress;
      expect(p.percent, 100);
      expect(p.hasNext, isFalse);
      expect(p.hasPrevious, isFalse);
    });
  });

  group('ReaderController resume + bounds', () {
    test('resumes the saved page index', () async {
      final c = _container(const ReaderLocator(
        locatorType: 'txt_offset',
        locatorValue: '0',
        pageNumber: 2,
        percent: 0,
      ));
      final ready = await _pumpReady(c, 'b');
      expect(ready.pageIndex, 2);
    });

    test('an out-of-range saved page falls back to 0', () async {
      final c = _container(const ReaderLocator(
        locatorType: 'txt_offset',
        locatorValue: 'not-a-number',
        pageNumber: 9999,
        percent: 0,
      ));
      final ready = await _pumpReady(c, 'b');
      expect(ready.pageIndex, 0);
    });

    test('next/previous do not move out of range', () async {
      final c = _container(null);
      await _pumpReady(c, 'b');
      final ctrl = c.read(readerControllerProvider('b').notifier);

      // At page 0, previous is a no-op.
      ctrl.previousPage();
      expect((c.read(readerControllerProvider('b')) as ReaderReady).pageIndex, 0);

      // Jump to the last page, then next is a no-op.
      ctrl.jumpToOffset(1 << 30);
      final last =
          (c.read(readerControllerProvider('b')) as ReaderReady).pageIndex;
      expect(last, greaterThan(0));
      ctrl.nextPage();
      expect(
        (c.read(readerControllerProvider('b')) as ReaderReady).pageIndex,
        last,
      );
    });
  });
}
