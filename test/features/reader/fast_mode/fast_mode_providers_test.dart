import 'dart:async';

import 'package:colibri/core/errors/failures.dart';
import 'package:colibri/core/result/result.dart';
import 'package:colibri/data/repositories/reader_repository.dart';
import 'package:colibri/features/reader/application/reader_providers.dart';
import 'package:colibri/features/reader/domain/pdf_book_source.dart';
import 'package:colibri/features/reader/domain/reader_chapter.dart';
import 'package:colibri/features/reader/domain/reader_document.dart';
import 'package:colibri/features/reader/domain/reader_locator.dart';
import 'package:colibri/features/reader/domain/reader_mode.dart';
import 'package:colibri/features/reader/fast_mode/application/fast_mode_providers.dart';
import 'package:colibri/features/reader/fast_mode/domain/fast_mode_playback_state.dart';
import 'package:colibri/features/reader/fast_mode/domain/fast_mode_settings.dart';
import 'package:colibri/features/reader/settings/application/reader_settings_providers.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

/// A repository whose [openBook] stays pending until the test completes it,
/// so the engine provider can be disposed mid-load.
class _PendingReaderRepo implements ReaderRepository {
  _PendingReaderRepo(this.opened);

  final Completer<Result<ReaderDocument>> opened;

  @override
  Future<Result<ReaderDocument>> openBook(String bookId) => opened.future;

  @override
  Future<Result<PdfBookSource>> openPdfBook(String bookId) async =>
      const Err(UnsupportedFormatFailure('Not a PDF book.'));

  @override
  Future<Result<ReaderLocator?>> getSavedLocator(String bookId) async =>
      const Ok(null);

  @override
  Future<Result<void>> saveLocator(
    String bookId,
    ReaderLocator locator, {
    ReaderMode mode = ReaderMode.normal,
  }) async =>
      const Ok(null);
}

ReaderDocument _doc() => const ReaderDocument(
      bookId: 'b',
      title: 't',
      format: 'txt',
      chapters: <ReaderChapter>[
        ReaderChapter(index: 0, title: 't', text: 'one two three'),
      ],
    );

ProviderContainer _container(ReaderRepository repo) => ProviderContainer(
      overrides: <Override>[
        readerRepositoryProvider.overrideWithValue(repo),
        fastModeSettingsProvider.overrideWithValue(FastModeSettings.defaults()),
      ],
    );

void main() {
  test('disposing the provider mid-load does not touch the disposed engine',
      () async {
    final opened = Completer<Result<ReaderDocument>>();
    final container = _container(_PendingReaderRepo(opened));

    // Start the load, then tear the provider down while openBook is pending.
    container.read(fastModeEngineProvider('b'));
    container.dispose();

    // Completing now must NOT crash: without the disposed-flag bail-out this
    // would call loadTokens/notifyListeners on a disposed ChangeNotifier and
    // surface an unhandled async error that fails this test.
    opened.complete(Ok(_doc()));
    await pumpEventQueue();
  });

  test('a kept-alive engine still loads tokens and resumes ready', () async {
    final opened = Completer<Result<ReaderDocument>>();
    final container = _container(_PendingReaderRepo(opened));
    addTearDown(container.dispose);

    // Listening keeps the autoDispose element alive across the await.
    container.listen(fastModeEngineProvider('b'), (_, __) {});
    final engine = container.read(fastModeEngineProvider('b'));

    opened.complete(Ok(_doc()));
    await pumpEventQueue();

    expect(engine.state.playback, FastModePlaybackState.ready);
    expect(engine.state.tokens, isNotEmpty);
  });
}
