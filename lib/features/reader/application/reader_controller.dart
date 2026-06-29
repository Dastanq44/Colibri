import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/errors/failures.dart';
import '../../../core/result/result.dart';
import '../domain/reader_document.dart';
import '../domain/reader_locator.dart';
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
/// position on each page turn.
class ReaderController extends FamilyNotifier<ReaderState, String> {
  @override
  ReaderState build(String bookId) {
    _load();
    return const ReaderLoading();
  }

  Future<void> _load() async {
    final repo = ref.read(readerRepositoryProvider);
    switch (await repo.openBook(arg)) {
      case Err(failure: final f):
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

  Future<void> _persist() async {
    final s = state;
    if (s is! ReaderReady) return;
    final page = s.currentPage;
    final locator = ReaderLocator(
      locatorType: 'txt_offset',
      locatorValue: page.startOffset.toString(),
      pageNumber: s.pageIndex,
      percent: s.progress.percent,
    );
    await ref.read(readerRepositoryProvider).saveLocator(arg, locator);
  }
}

final readerControllerProvider =
    NotifierProvider.family<ReaderController, ReaderState, String>(
  ReaderController.new,
);
