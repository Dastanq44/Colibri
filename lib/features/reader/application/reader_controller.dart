import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/errors/failures.dart';
import '../../../core/result/result.dart';
import '../../../data/repositories/analytics_repository.dart';
import '../domain/pdf_book_source.dart';
import '../domain/reader_document.dart';
import '../domain/reader_locator.dart';
import '../domain/reader_locator_types.dart';
import '../domain/reader_page.dart';
import '../domain/reader_progress.dart';
import '../domain/toc_entry.dart';
import 'reader_providers.dart';

enum ReaderUnsupportedReason { pdf, malformedEpub, emptyText, generic }

/// State machine for the portrait TXT reader.
sealed class ReaderState {
  const ReaderState();
}

class ReaderLoading extends ReaderState {
  const ReaderLoading();
}

class ReaderEmpty extends ReaderState {
  const ReaderEmpty();
}

class ReaderUnsupported extends ReaderState {
  const ReaderUnsupported(this.reason);
  final ReaderUnsupportedReason reason;
}

class ReaderFailed extends ReaderState {
  const ReaderFailed();
}

/// A PDF book, rendered by the native page viewer (TASK-0704). PDFs never
/// enter fast mode in MVP, so orientation changes are ignored in this state.
class ReaderPdfReady extends ReaderState {
  const ReaderPdfReady(this.source);

  final PdfBookSource source;
}

class ReaderReady extends ReaderState {
  const ReaderReady({
    required this.document,
    required this.pages,
    required this.pageIndex,
    required this.toc,
  });

  final ReaderDocument document;
  final List<ReaderPage> pages;
  final int pageIndex;
  final List<TocEntry> toc;

  ReaderPage get currentPage => pages[pageIndex];

  ReaderProgress get progress => ReaderProgress(
        pageIndex: pageIndex,
        pageCount: pages.length,
        percent: pages.length <= 1
            ? 100
            : (pageIndex / (pages.length - 1)) * 100,
      );

  ReaderReady copyWith({int? pageIndex}) => ReaderReady(
        document: document,
        pages: pages,
        pageIndex: pageIndex ?? this.pageIndex,
        toc: toc,
      );
}

/// Loads a book, paginates it, resumes from saved progress, and persists the
/// position on each page turn. Auto-disposed so leaving the reader frees its
/// state; ReaderScreen saves the position before it unmounts.
class ReaderController extends AutoDisposeFamilyNotifier<ReaderState, String> {
  @override
  ReaderState build(String bookId) {
    _load();
    return const ReaderLoading();
  }

  Future<void> _load() async {
    final repo = ref.read(readerRepositoryProvider);
    switch (await repo.openBook(arg)) {
      case Err(failure: final f):
        // PDFs are not text documents: openBook signals unsupported and the
        // page viewer takes over.
        if (f is UnsupportedFormatFailure) {
          switch (await repo.openPdfBook(arg)) {
            case Ok(value: final source):
              state = ReaderPdfReady(source);
            case Err(failure: final pdfFailure):
              state = _mapFailure(pdfFailure);
          }
          return;
        }
        state = _mapFailure(f);
      case Ok(value: final doc):
        final pages =
            ref.read(textPaginationServiceProvider).paginate(doc.fullText);
        if (pages.isEmpty) {
          state = const ReaderEmpty();
          return;
        }
        var index = 0;
        if (await repo.getSavedLocator(arg)
            case Ok(value: final ReaderLocator loc)) {
          index = _resolveIndex(pages, loc);
          // Keep the exact saved offset so the first fit-pagination anchors on
          // it precisely, rather than on the placeholder page's start (which
          // would round the position back to that page's beginning).
          if (ReaderLocatorTypes.isOffset(loc.locatorType)) {
            _pendingAnchorOffset = int.tryParse(loc.locatorValue);
          }
        }
        state = ReaderReady(
          document: doc,
          pages: pages,
          pageIndex: index,
          toc: _buildToc(doc),
        );
    }
  }

  List<TocEntry> _buildToc(ReaderDocument doc) {
    final offsets = doc.chapterStartOffsets();
    return <TocEntry>[
      for (var i = 0; i < doc.chapters.length; i++)
        TocEntry(
          title: doc.chapters[i].title,
          chapterIndex: i,
          startOffset: offsets[i],
        ),
    ];
  }

  ReaderState _mapFailure(Failure failure) {
    return switch (failure) {
      UnsupportedFormatFailure() =>
        const ReaderUnsupported(ReaderUnsupportedReason.pdf),
      MalformedBookFailure() =>
        const ReaderUnsupported(ReaderUnsupportedReason.malformedEpub),
      EmptyBookFailure() =>
        const ReaderUnsupported(ReaderUnsupportedReason.emptyText),
      _ => const ReaderFailed(),
    };
  }

  int _resolveIndex(List<ReaderPage> pages, ReaderLocator locator) {
    final byPage = locator.pageNumber;
    if (byPage != null && byPage >= 0 && byPage < pages.length) return byPage;
    final offset = int.tryParse(locator.locatorValue) ?? 0;
    final idx = pages.indexWhere(
      (p) => offset >= p.startOffset && offset < p.endOffset,
    );
    return idx < 0 ? 0 : idx;
  }

  void nextPage() {
    final s = state;
    if (s is! ReaderReady || !s.progress.hasNext) return;
    state = s.copyWith(pageIndex: s.pageIndex + 1);
    _persist();
  }

  void previousPage() {
    final s = state;
    if (s is! ReaderReady || !s.progress.hasPrevious) return;
    state = s.copyWith(pageIndex: s.pageIndex - 1);
    _persist();
  }

  /// Saves the current position (also called on reader exit/pause).
  Future<void> saveNow() => _persist();

  /// Source start offset of the current page (for handing off to fast mode).
  int? get currentStartOffset {
    final s = state;
    return s is ReaderReady ? s.currentPage.startOffset : null;
  }

  /// Jumps to the page containing [offset] (used to resume the normal reader
  /// from a fast-mode position).
  void jumpToOffset(int offset) {
    final s = state;
    if (s is! ReaderReady) return;
    var index = s.pages.indexWhere(
      (p) => offset >= p.startOffset && offset < p.endOffset,
    );
    if (index < 0) index = offset <= 0 ? 0 : s.pages.length - 1;
    if (index != s.pageIndex) {
      state = s.copyWith(pageIndex: index);
      _persist();
    }
  }

  /// Jumps to a table-of-contents entry's chapter and saves progress.
  void jumpToChapter(TocEntry entry) => jumpToOffset(entry.startOffset);

  String? _viewportKey;

  /// Exact reading offset to anchor the first fit-pagination on (from a
  /// resumed locator); consumed on the first [applyViewport].
  int? _pendingAnchorOffset;

  /// Re-paginates so each page fills the given text area without overflow
  /// (called by the reader view with its measured size + current font style).
  /// Idempotent per (size, style) — a no-op when nothing changed. Keeps the
  /// reading position by re-anchoring on the current page's start offset;
  /// does not persist (the saved offset is unchanged).
  void applyViewport({
    required double maxWidth,
    required double maxHeight,
    required TextStyle style,
    required TextScaler textScaler,
  }) {
    final s = state;
    if (s is! ReaderReady) return;
    if (maxWidth < 40 || maxHeight < 40) return; // degenerate/transient size
    final key = '${maxWidth.round()}x${maxHeight.round()}'
        '|${style.fontSize}|${style.height}|${style.letterSpacing}'
        '|${style.fontFamily}|${textScaler.scale(100).round()}';
    if (key == _viewportKey) return;

    final anchor = _pendingAnchorOffset ?? s.currentPage.startOffset;
    _pendingAnchorOffset = null;
    final pages = ref.read(textPaginationServiceProvider).paginateToFit(
          s.document.fullText,
          maxWidth: maxWidth,
          maxHeight: maxHeight,
          style: style,
          textScaler: textScaler,
        );
    if (pages.isEmpty) return;
    _viewportKey = key;
    var index = pages.indexWhere(
      (p) => anchor >= p.startOffset && anchor < p.endOffset,
    );
    if (index < 0) index = 0;
    state = ReaderReady(
      document: s.document,
      pages: pages,
      pageIndex: index,
      toc: s.toc,
    );
  }

  /// Persists PDF progress by 1-based page number (TASK-0704). Percent
  /// mirrors the text reader's convention: the last page reads 100%.
  Future<void> savePdfPage({
    required int pageNumber,
    required int pageCount,
  }) async {
    if (state is! ReaderPdfReady || pageNumber < 1 || pageCount < 1) return;
    final percent = pageCount <= 1
        ? 100.0
        : ((pageNumber - 1) / (pageCount - 1)) * 100;
    await ref.read(readerRepositoryProvider).saveLocator(
          arg,
          ReaderLocator(
            locatorType: ReaderLocatorTypes.pdfPage,
            locatorValue: '$pageNumber',
            pageNumber: pageNumber,
            percent: percent.clamp(0.0, 100.0),
          ),
        );
  }

  Future<void> _persist() async {
    final s = state;
    if (s is! ReaderReady) return;
    final page = s.currentPage;
    final locator = ReaderLocator(
      locatorType: ReaderLocatorTypes.textOffset,
      locatorValue: page.startOffset.toString(),
      pageNumber: s.pageIndex,
      percent: s.progress.percent,
    );
    await ref.read(readerRepositoryProvider).saveLocator(arg, locator);
    // TASK-1503: checkpoint tracking (position only — never book content).
    unawaited(ref.read(analyticsRepositoryProvider).logEvent(
      'progress_checkpoint_saved',
      params: {'percent': s.progress.percent.round()},
    ));
  }
}

final readerControllerProvider =
    NotifierProvider.autoDispose.family<ReaderController, ReaderState, String>(
  ReaderController.new,
);
