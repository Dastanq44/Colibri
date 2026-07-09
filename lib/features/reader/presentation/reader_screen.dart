import 'dart:async';

import 'package:animations/animations.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/gestures.dart' show LongPressGestureRecognizer;
import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter/services.dart'
    show DeviceOrientation, HapticFeedback, SystemChrome, SystemUiOverlayStyle;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/localization/generated/app_localizations.dart';
import '../../../app/theme/reader_theme.dart';
import '../../../app/widgets/app_loader.dart';
import '../../../app/widgets/confirm_sheet.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/result/result.dart';
import '../../../data/repositories/analytics_repository.dart';
import '../../notes/application/notes_providers.dart';
import '../../notes/presentation/annotations_sheet.dart';
import '../../sync/application/sync_providers.dart';
import '../../sync/domain/progress_conflict_policy.dart';
import '../../sync/domain/remote_progress.dart';
import '../application/reader_controller.dart';
import '../application/reader_position_policy.dart';
import '../application/reader_providers.dart';
import '../domain/reader_locator.dart';
import '../domain/reader_locator_types.dart';
import '../domain/reader_mode.dart';
import '../domain/reader_page.dart';
import '../domain/reader_progress.dart';
import '../fast_mode/application/fast_mode_providers.dart';
import '../fast_mode/presentation/fast_reader_view.dart';
import '../pdf/presentation/pdf_reader_view.dart';
import '../settings/application/reader_settings_providers.dart';
import '../settings/domain/reader_settings.dart';
import '../settings/presentation/reader_settings_sheet.dart';
import 'search_sheet.dart';
import 'toc_sheet.dart';

/// The reader. Portrait = normal paged reader; landscape = fast mode (when the
/// book has extractable text). Orientation switches the mode *inside this
/// screen only* — the app is never globally orientation-locked. Mode lock
/// (persisted) freezes the current mode.
class ReaderScreen extends ConsumerStatefulWidget {
  const ReaderScreen({super.key, required this.bookId});

  final String bookId;

  @override
  ConsumerState<ReaderScreen> createState() => _ReaderScreenState();
}

class _ReaderScreenState extends ConsumerState<ReaderScreen>
    with WidgetsBindingObserver {
  ReaderMode _effectiveMode = ReaderMode.normal;
  ReaderMode? _pendingMode;
  Timer? _switchTimer;
  Orientation? _lastOrientation;

  /// Direction of the last page turn, for the page-transition animation
  /// (true = forward/next, false = backward/previous).
  bool _pageForward = true;

  /// Bumped only by an actual user page turn; the page transition keys on
  /// this so jumps (search/TOC/handoff) and re-pagination swap instantly
  /// instead of playing a spurious slide.
  int _pageTurnId = 0;

  /// Turns the page and arms the directional transition — only when a page
  /// actually exists in that direction (so a tap at the end doesn't animate).
  void _turnPage(ReaderReady state, {required bool forward}) {
    final can = forward ? state.progress.hasNext : state.progress.hasPrevious;
    if (can) {
      setState(() {
        _pageForward = forward;
        _pageTurnId++;
      });
    }
    final notifier = ref.read(readerControllerProvider(widget.bookId).notifier);
    forward ? notifier.nextPage() : notifier.previousPage();
  }

  // Reading-session tracking (plan §10.2): one session per continuous
  // stretch in a mode; mode switches roll the session over.
  String? _sessionId;
  DateTime? _sessionStartedAt;
  ReaderMode _sessionMode = ReaderMode.normal;
  int _sessionFastWordsStart = 0;

  Future<void> _startSession(ReaderMode mode) async {
    if (_sessionId != null) return;
    // Read providers before any await: this may race widget disposal.
    final sessions = ref.read(sessionRepositoryProvider);
    final analytics = ref.read(analyticsRepositoryProvider);
    _sessionMode = mode;
    _sessionStartedAt = DateTime.now();
    _sessionFastWordsStart = mode == ReaderMode.fast
        ? ref.read(fastModeEngineProvider(widget.bookId)).state.wordsRead
        : 0;
    _sessionId =
        await sessions.startSession(bookId: widget.bookId, mode: mode.wire);
    unawaited(analytics
        .logEvent('reading_session_started', params: {'mode': mode.wire}));
  }

  Future<void> _endSession() async {
    final id = _sessionId;
    final startedAt = _sessionStartedAt;
    if (id == null || startedAt == null) return;
    _sessionId = null;
    _sessionStartedAt = null;
    // Read providers before any await: dispose calls this fire-and-forget.
    final sessions = ref.read(sessionRepositoryProvider);
    final analytics = ref.read(analyticsRepositoryProvider);
    final duration = DateTime.now().difference(startedAt);
    int? words;
    int? avgWpm;
    if (_sessionMode == ReaderMode.fast) {
      final engineWords =
          ref.read(fastModeEngineProvider(widget.bookId)).state.wordsRead;
      words = (engineWords - _sessionFastWordsStart).clamp(0, 1 << 31);
      // A measured pace needs a meaningful window and actual words.
      if (duration.inSeconds >= 30 && words > 0) {
        avgWpm = (words * 60 / duration.inSeconds).round();
      }
    }
    await sessions.endSession(
      id,
      duration: duration,
      wordsRead: words,
      avgWpm: avgWpm,
    );
    unawaited(analytics.logEvent(
      'reading_session_ended',
      params: {
        'mode': _sessionMode.wire,
        'duration_seconds': duration.inSeconds,
        if (avgWpm != null) 'avg_wpm': avgWpm,
      },
    ));
  }

  Future<void> _rolloverSession(ReaderMode to) async {
    await _endSession();
    await _startSession(to);
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    // The app is portrait-locked globally; only the reader may rotate
    // (landscape enters fast mode). Restored on dispose.
    SystemChrome.setPreferredOrientations(const <DeviceOrientation>[
      DeviceOrientation.portraitUp,
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Reacting here (not in build) keeps timer/setState side-effects out of the
    // build phase. MediaQuery is a dependency, so this re-runs on rotation.
    final orientation = MediaQuery.orientationOf(context);
    if (orientation != _lastOrientation) {
      _lastOrientation = orientation;
      _reactToOrientation(orientation);
    }
  }

  @override
  void dispose() {
    _switchTimer?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    // Back to the app-wide portrait lock.
    SystemChrome.setPreferredOrientations(
      const <DeviceOrientation>[DeviceOrientation.portraitUp],
    );
    // Final save (engine + reader are still alive during dispose). Exactly one
    // save — the active mode's; the inactive surface was synced at the last
    // handoff and its position would be stale here.
    try {
      saveActiveModePosition(
        mode: _effectiveMode,
        saveNormal: () => ref
            .read(readerControllerProvider(widget.bookId).notifier)
            .saveNow(),
        saveFast: () =>
            ref.read(fastModeEngineProvider(widget.bookId)).savePosition(),
      );
      unawaited(_endSession());
    } catch (_) {
      // Ignore — never throw from dispose.
    }
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.inactive) {
      saveActiveModePosition(
        mode: _effectiveMode,
        saveNormal: () => ref
            .read(readerControllerProvider(widget.bookId).notifier)
            .saveNow(),
        // Pause (not just save) so fast mode resumes paused, not playing.
        saveFast: () => ref.read(fastModeEngineProvider(widget.bookId)).pause(),
      );
      unawaited(_endSession());
    } else if (state == AppLifecycleState.resumed) {
      // A new stretch of reading begins when the app comes back.
      if (ref.read(readerControllerProvider(widget.bookId)) is ReaderReady) {
        unawaited(_startSession(_effectiveMode));
      }
    }
  }

  bool get _modeLocked =>
      ref.read(readerSettingsProvider).valueOrNull?.modeLockEnabled ?? false;

  /// Fires [feedback] only when the persisted haptics setting allows it
  /// (TASK-1007). Fails closed (`?? false`): while settings are still loading
  /// we must not vibrate against a persisted opt-out. Fire-and-forget:
  /// haptics must never block or throw into UI.
  void _haptic(Future<void> Function() feedback) {
    final enabled =
        ref.read(readerSettingsProvider).valueOrNull?.hapticsEnabled ?? false;
    if (enabled) unawaited(feedback());
  }

  /// Debounced orientation → mode switch (stability threshold avoids flips).
  /// [lockOverride] supplies a just-written lock value that the settings
  /// stream may not reflect yet.
  void _reactToOrientation(Orientation orientation, {bool? lockOverride}) {
    if (lockOverride ?? _modeLocked) {
      _switchTimer?.cancel();
      _pendingMode = null;
      return;
    }
    final desired = orientation == Orientation.landscape
        ? ReaderMode.fast
        : ReaderMode.normal;
    if (desired == _effectiveMode) {
      _switchTimer?.cancel();
      _pendingMode = null;
      return;
    }
    if (_pendingMode == desired) return;
    _pendingMode = desired;
    _switchTimer?.cancel();
    _switchTimer = Timer(AppConstants.modeSwitchStabilityThreshold, () {
      if (mounted) _commitModeSwitch(desired);
    });
  }

  void _commitModeSwitch(ReaderMode to) {
    final readerState = ref.read(readerControllerProvider(widget.bookId));
    // PDFs never mode-switch (no fast mode in MVP).
    if (readerState is ReaderPdfReady) {
      _pendingMode = null;
      return;
    }
    _handoffPosition(to);
    // Haptic only for a real fast-mode entry, not a switch armed while the
    // book was still loading.
    if (to == ReaderMode.fast && readerState is ReaderReady) {
      _haptic(HapticFeedback.lightImpact);
    }
    if (readerState is ReaderReady) {
      _rolloverSession(to);
      unawaited(ref.read(analyticsRepositoryProvider).logEvent(
            to == ReaderMode.fast
                ? 'mode_switch_portrait_to_fast'
                : 'mode_switch_fast_to_portrait',
          ));
    }
    setState(() {
      _effectiveMode = to;
      _pendingMode = null;
    });
  }

  /// Carries the current text position across the mode boundary.
  void _handoffPosition(ReaderMode to) {
    final reader = ref.read(readerControllerProvider(widget.bookId).notifier);
    final engine = ref.read(fastModeEngineProvider(widget.bookId));
    if (to == ReaderMode.fast) {
      final state = ref.read(readerControllerProvider(widget.bookId));
      if (state is ReaderReady) {
        final page = state.currentPage;
        final marked = state.highlightOffset;
        if (marked != null) {
          // A word the reader long-pressed (or the resume marker) is an
          // explicit "start fast mode here" point — always honour it.
          engine.seekToOffset(marked);
        } else if (shouldSeekFastEngine(
          // Otherwise seek only when the engine's token is outside the current
          // page; inside it the engine's finer position wins (no rewind).
          engineOffset: engine.currentStartOffset,
          pageStart: page.startOffset,
          pageEnd: page.endOffset,
        )) {
          engine.seekToOffset(page.startOffset);
        }
      }
      engine.pause(); // fast mode starts paused
    } else {
      engine.pause();
      final offset = engine.currentStartOffset;
      // Underline the last word shown in fast mode as the resume marker.
      if (offset != null) reader.setResumeHighlight(offset);
    }
  }

  void _toggleModeLock(bool currentlyLocked) {
    final locked = !currentlyLocked;
    _haptic(HapticFeedback.selectionClick);
    unawaited(ref
        .read(analyticsRepositoryProvider)
        .logEvent('mode_lock_toggled', params: {'locked': locked}));
    ref.read(readerSettingsRepositoryProvider).setModeLock(locked);
    // React with the fresh value now — the settings stream only re-emits after
    // the async write lands, so reading it here would race (and lose) the
    // toggle.
    if (locked) {
      _switchTimer?.cancel();
      _pendingMode = null;
    } else {
      _reactToOrientation(
        MediaQuery.orientationOf(context),
        lockOverride: false,
      );
    }
  }

  Future<void> _openReaderMenu(ReaderReady state) async {
    final l10n = AppLocalizations.of(context);
    // The reader's own sheets follow the chosen reading theme, not the app
    // chrome theme.
    final palette = ReaderPalette.of(
      ref.read(readerSettingsProvider).valueOrNull?.theme ??
          ReaderThemeVariant.light,
    );
    Widget row(IconData icon, String title, String value, BuildContext ctx) =>
        ListTile(
          leading: Icon(icon, color: palette.text),
          title: Text(title, style: TextStyle(color: palette.text)),
          onTap: () => Navigator.pop(ctx, value),
        );
    final choice = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: palette.background,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            row(CupertinoIcons.list_bullet, l10n.tableOfContents, 'toc', ctx),
            row(CupertinoIcons.search, l10n.readerSearchInBook, 'search', ctx),
            row(CupertinoIcons.bookmark, l10n.readerAddBookmark,
                'add_bookmark', ctx),
            row(CupertinoIcons.square_pencil, l10n.readerAddNote, 'add_note',
                ctx),
            row(CupertinoIcons.bookmark_fill, l10n.readerAnnotations,
                'annotations', ctx),
            row(CupertinoIcons.gear, l10n.readerSettingsTitle, 'settings', ctx),
          ],
        ),
      ),
    );
    if (!mounted) return;
    switch (choice) {
      case 'toc':
        await showModalBottomSheet<void>(
          context: context,
          builder: (_) => TocSheet(
            toc: state.toc,
            onSelect: (entry) => ref
                .read(readerControllerProvider(widget.bookId).notifier)
                .jumpToChapter(entry),
          ),
        );
      case 'search':
        await _openSearch(state);
      case 'add_bookmark':
        await _addBookmark(state);
      case 'add_note':
        await _addNote(state);
      case 'annotations':
        await _openAnnotations();
      case 'settings':
        await showModalBottomSheet<void>(
          context: context,
          isScrollControlled: true,
          showDragHandle: true,
          backgroundColor: palette.background,
          builder: (_) => const ReaderSettingsSheet(),
        );
    }
  }

  /// The current page's position, as stored on bookmarks/notes (TASK-1101).
  ReaderLocator _currentLocator(ReaderReady state) => ReaderLocator(
        locatorType: ReaderLocatorTypes.textOffset,
        locatorValue: state.currentPage.startOffset.toString(),
        pageNumber: state.pageIndex,
        percent: state.progress.percent,
      );

  Future<void> _addBookmark(ReaderReady state) async {
    final l10n = AppLocalizations.of(context);
    final label = await _promptText(
      title: l10n.readerAddBookmark,
      hint: l10n.bookmarkLabelHint,
    );
    if (label == null || !mounted) return; // dialog dismissed
    final result = await ref.read(notesRepositoryProvider).createBookmark(
          widget.bookId,
          locator: _currentLocator(state),
          label: label,
        );
    if (result is Ok && mounted) {
      unawaited(
          ref.read(analyticsRepositoryProvider).logEvent('bookmark_created'));
    }
    _showResultSnack(result is Ok ? l10n.bookmarkAdded : null);
  }

  Future<void> _addNote(ReaderReady state) async {
    final l10n = AppLocalizations.of(context);
    final text = await _promptText(
      title: l10n.readerAddNote,
      hint: l10n.noteTextHint,
      multiline: true,
      requireText: true,
    );
    if (text == null || text.trim().isEmpty || !mounted) return;
    final result = await ref.read(notesRepositoryProvider).createNote(
          widget.bookId,
          locator: _currentLocator(state),
          noteText: text,
        );
    if (result is Ok && mounted) {
      unawaited(
          ref.read(analyticsRepositoryProvider).logEvent('note_created'));
    }
    _showResultSnack(result is Ok ? l10n.noteAdded : null);
  }

  bool _cloudPositionChecked = false;

  /// Compares the cloud reading position against local once per open
  /// (TASK-1203): a significantly *later* cloud position offers a choice;
  /// anything else resolves silently. Failures never block reading.
  Future<void> _maybePromptCloudPosition(ReaderReady state) async {
    if (_cloudPositionChecked) return;
    _cloudPositionChecked = true;

    final result =
        await ref.read(syncRepositoryProvider).fetchRemoteProgress(widget.bookId);
    if (!mounted || result is! Ok<RemoteProgress?>) return;
    final remote = result.value;
    final offset = remote?.textOffset;
    if (remote == null || offset == null) return;

    final local = ref.read(readerControllerProvider(widget.bookId));
    if (local is! ReaderReady) return;
    if (!isSignificantProgressConflict(
      localPercent: local.progress.percent,
      remotePercent: remote.percent,
    )) {
      return;
    }

    final l10n = AppLocalizations.of(context);
    final useCloud = await showCupertinoDialog<bool>(
      context: context,
      builder: (ctx) => CupertinoAlertDialog(
        title: Text(l10n.syncConflictTitle),
        content: Text(l10n.syncConflictBody(
          local.progress.percent.round(),
          remote.percent.round(),
        )),
        actions: <Widget>[
          CupertinoDialogAction(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(l10n.syncConflictKeepLocal),
          ),
          CupertinoDialogAction(
            isDefaultAction: true,
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(l10n.syncConflictUseCloud),
          ),
        ],
      ),
    );
    if (useCloud == true && mounted) _jumpTo(offset);
  }

  /// Jumps both reading surfaces to [offset]. The device may have rotated
  /// while a sheet was open (mode switched underneath it); seeding the fast
  /// engine too keeps the jump from being clobbered at the next handoff.
  void _jumpTo(int offset) {
    ref
        .read(readerControllerProvider(widget.bookId).notifier)
        .jumpToOffset(offset);
    if (_effectiveMode == ReaderMode.fast) {
      ref.read(fastModeEngineProvider(widget.bookId)).seekToOffset(offset);
    }
  }

  Future<void> _openSearch(ReaderReady state) async {
    await showModalBottomSheet<void>(
      context: context,
      // Scroll-controlled so the sheet rises above the keyboard.
      isScrollControlled: true,
      builder: (sheetCtx) => SearchSheet(
        fullText: state.document.fullText,
        onJump: (offset) {
          if (ModalRoute.of(sheetCtx)?.isCurrent ?? false) {
            Navigator.pop(sheetCtx);
          }
          _jumpTo(offset);
        },
      ),
    );
  }

  Future<void> _openAnnotations() async {
    // Default (capped) sheet height: long lists scroll inside the sheet
    // instead of covering the whole reader.
    await showModalBottomSheet<void>(
      context: context,
      builder: (sheetCtx) => AnnotationsSheet(
        bookId: widget.bookId,
        onJump: (offset) {
          // Guard against a double-tap popping the reader route as well.
          if (ModalRoute.of(sheetCtx)?.isCurrent ?? false) {
            Navigator.pop(sheetCtx);
          }
          _jumpTo(offset);
        },
      ),
    );
  }

  /// Confirmation (or the localized failure message when [successText] is
  /// null) after an annotation write.
  void _showResultSnack(String? successText) {
    if (!mounted) return;
    final l10n = AppLocalizations.of(context);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(successText ?? l10n.annotationSaveFailed)),
    );
  }

  /// Single-field text prompt. Returns null when dismissed/canceled; an empty
  /// string is a valid "no label" submit unless [requireText] disables it.
  Future<String?> _promptText({
    required String title,
    required String hint,
    bool multiline = false,
    bool requireText = false,
  }) {
    final l10n = AppLocalizations.of(context);
    // Modern floating card, themed to the active reading palette.
    final palette = ReaderPalette.of(
      ref.read(readerSettingsProvider).valueOrNull?.theme ??
          ReaderThemeVariant.light,
    );
    return showModernPromptSheet(
      context,
      title: title,
      hint: hint,
      confirmLabel: l10n.dialogAdd,
      cancelLabel: l10n.dialogCancel,
      multiline: multiline,
      requireText: requireText,
      background: palette.background,
      foreground: palette.text,
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    // Completion haptic (TASK-1007): fires when the normal reader arrives at
    // the last page from an earlier one. Fast mode's completion haptic comes
    // from the engine listener in FastReaderView.
    ref.listen(readerControllerProvider(widget.bookId), (previous, next) {
      if (previous is ReaderReady &&
          next is ReaderReady &&
          previous.progress.hasNext &&
          !next.progress.hasNext) {
        _haptic(HapticFeedback.mediumImpact);
      }
      // First ready: session starts, cloud position is checked once, and
      // the open is tracked (TASK-1203 / TASK-1503).
      if (previous is! ReaderReady && next is ReaderReady) {
        _startSession(_effectiveMode);
        _maybePromptCloudPosition(next);
        unawaited(ref
            .read(analyticsRepositoryProvider)
            .logEvent('book_opened', params: {'format': next.document.format}));
      }
    });

    final state = ref.watch(readerControllerProvider(widget.bookId));
    final settings =
        ref.watch(readerSettingsProvider).valueOrNull ?? ReaderSettings.defaults();

    // If mode lock just turned on, cancel any pending auto-switch.
    if (settings.modeLockEnabled) {
      _switchTimer?.cancel();
      _pendingMode = null;
    }

    // Keep the fast engine alive while a readable book is open (instant
    // switch). Watching alone never persists the engine's position: exit
    // saves go through the active mode only (see dispose above).
    if (state is ReaderReady) {
      ref.watch(fastModeEngineProvider(widget.bookId));
    }

    return switch (state) {
      ReaderLoading() => _Scaffold(
          title: l10n.readerTitle,
          child: const Center(child: AppLoader()),
        ),
      ReaderEmpty() => _Scaffold(
          title: l10n.readerTitle,
          child: _Message(icon: CupertinoIcons.book, text: l10n.readerEmpty),
        ),
      ReaderUnsupported(:final reason) => _Scaffold(
          title: l10n.readerUnsupportedTitle,
          child: _Message(
            icon: CupertinoIcons.nosign,
            text: _unsupportedText(l10n, reason),
          ),
        ),
      ReaderFailed() => _Scaffold(
          title: l10n.readerTitle,
          child: _Message(icon: CupertinoIcons.exclamationmark_circle, text: l10n.readerOpenError),
        ),
      ReaderPdfReady(:final source) => PdfReaderView(source: source),
      ReaderReady() => _effectiveMode == ReaderMode.fast
          ? FastReaderView(
              bookId: widget.bookId,
              modeLocked: settings.modeLockEnabled,
              onToggleModeLock: () => _toggleModeLock(settings.modeLockEnabled),
            )
          : _NormalReaderView(
              l10n: l10n,
              state: state,
              settings: settings,
              modeLocked: settings.modeLockEnabled,
              pageForward: _pageForward,
              pageTurnId: _pageTurnId,
              onToggleModeLock: () => _toggleModeLock(settings.modeLockEnabled),
              onOpenMenu: () => _openReaderMenu(state),
              onPrevious: () => _turnPage(state, forward: false),
              onNext: () => _turnPage(state, forward: true),
              onWordLongPress: (offset) {
                _haptic(HapticFeedback.selectionClick);
                ref
                    .read(readerControllerProvider(widget.bookId).notifier)
                    .setResumeHighlight(offset);
              },
              // Suppress re-pagination while a mode switch is pending: the
              // landscape normal layout would be discarded when fast mode
              // commits (~500ms), so paginating the whole book for it is waste.
              onViewport: _pendingMode != null
                  ? null
                  : (maxWidth, maxHeight, style, scaler) {
                      ref
                          .read(readerControllerProvider(widget.bookId).notifier)
                          .applyViewport(
                            maxWidth: maxWidth,
                            maxHeight: maxHeight,
                            style: style,
                            textScaler: scaler,
                          );
                    },
            ),
    };
  }

  String _unsupportedText(AppLocalizations l10n, ReaderUnsupportedReason reason) =>
      switch (reason) {
        ReaderUnsupportedReason.pdf => l10n.readerPdfComingSoon,
        ReaderUnsupportedReason.malformedEpub => l10n.readerEpubError,
        ReaderUnsupportedReason.emptyText => l10n.readerNoText,
        ReaderUnsupportedReason.generic => l10n.readerUnsupportedTitle,
      };
}

class _Scaffold extends StatelessWidget {
  const _Scaffold({required this.title, required this.child});

  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) =>
      Scaffold(appBar: AppBar(title: Text(title)), body: child);
}

class _Message extends StatelessWidget {
  const _Message({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Icon(icon, size: 56, color: theme.colorScheme.primary),
            const SizedBox(height: 16),
            Text(text, textAlign: TextAlign.center),
          ],
        ),
      ),
    );
  }
}

class _NormalReaderView extends StatelessWidget {
  const _NormalReaderView({
    required this.l10n,
    required this.state,
    required this.settings,
    required this.modeLocked,
    required this.pageForward,
    required this.pageTurnId,
    required this.onToggleModeLock,
    required this.onOpenMenu,
    required this.onPrevious,
    required this.onNext,
    required this.onViewport,
    required this.onWordLongPress,
  });

  static const EdgeInsets _pagePadding =
      EdgeInsets.symmetric(horizontal: 24, vertical: 16);
  static const Duration _turnDuration = Duration(milliseconds: 300);

  final AppLocalizations l10n;
  final ReaderReady state;
  final ReaderSettings settings;
  final bool modeLocked;
  final bool pageForward;
  final int pageTurnId;
  final VoidCallback onToggleModeLock;
  final VoidCallback onOpenMenu;
  final VoidCallback onPrevious;
  final VoidCallback onNext;

  /// Reports the measured text area + style so the controller can re-paginate
  /// to fit (see [ReaderController.applyViewport]). Null while a mode switch
  /// is pending, to skip paginating a soon-discarded layout.
  final void Function(
    double maxWidth,
    double maxHeight,
    TextStyle style,
    TextScaler scaler,
  )? onViewport;

  /// Called when the reader long-presses a word, with its source offset — used
  /// to move the underlined resume marker ("continue from here").
  final void Function(int offset) onWordLongPress;

  @override
  Widget build(BuildContext context) {
    final palette = ReaderPalette.of(settings.theme);
    final textStyle = settings.fontFamily.applyTo(TextStyle(
      fontSize: settings.fontSize.toDouble(),
      height: settings.lineHeight,
      letterSpacing: settings.letterSpacing,
      color: palette.text,
    ));
    final animate = settings.pageAnimationEnabled &&
        !settings.reducedMotion &&
        !MediaQuery.disableAnimationsOf(context);

    // Chrome (app bar + bottom bar) follows the chosen reading theme so the
    // whole screen changes together instead of a default-theme frame around a
    // themed page.
    final barBrightness =
        ThemeData.estimateBrightnessForColor(palette.background);
    return Scaffold(
      backgroundColor: palette.background,
      appBar: AppBar(
        backgroundColor: palette.background,
        foregroundColor: palette.text,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        systemOverlayStyle: barBrightness == Brightness.dark
            ? SystemUiOverlayStyle.light
            : SystemUiOverlayStyle.dark,
        title: Text(state.document.title),
      ),
      body: Column(
        children: <Widget>[
          Expanded(
            child: LayoutBuilder(
              builder: (context, constraints) {
                // Re-paginate to fill this exact area (after the frame, so we
                // never mutate state mid-build). No-op when nothing changed.
                final report = onViewport;
                if (report != null) {
                  final scaler = MediaQuery.textScalerOf(context);
                  final maxWidth =
                      constraints.maxWidth - _pagePadding.horizontal;
                  final maxHeight =
                      constraints.maxHeight - _pagePadding.vertical;
                  WidgetsBinding.instance.addPostFrameCallback((_) {
                    report(maxWidth, maxHeight, textStyle, scaler);
                  });
                }

                return Semantics(
                  customSemanticsActions: <CustomSemanticsAction, VoidCallback>{
                    CustomSemanticsAction(label: l10n.readerPreviousPage):
                        onPrevious,
                    CustomSemanticsAction(label: l10n.readerNextPage): onNext,
                  },
                  child: GestureDetector(
                    behavior: HitTestBehavior.translucent,
                    onTapUp: (details) {
                      if (details.localPosition.dx < constraints.maxWidth / 2) {
                        onPrevious();
                      } else {
                        onNext();
                      }
                    },
                    // Shared-axis (horizontal) page turn: the old page fades
                    // and slides off, the new one fades and slides in from the
                    // turn direction. Instant when animation is off/reduced.
                    child: PageTransitionSwitcher(
                      duration: animate ? _turnDuration : Duration.zero,
                      reverse: !pageForward,
                      transitionBuilder: (child, primary, secondary) =>
                          SharedAxisTransition(
                        animation: primary,
                        secondaryAnimation: secondary,
                        transitionType: SharedAxisTransitionType.horizontal,
                        fillColor: palette.background,
                        child: child,
                      ),
                      child: KeyedSubtree(
                        // Key on the user-turn id, not pageIndex: jumps and
                        // re-pagination update content in place (no animation);
                        // only a real turn changes the key and slides.
                        key: ValueKey<int>(pageTurnId),
                        // Fitted page fills the area without scrolling; ClipRect
                        // guards the one transient frame before the first fit.
                        child: ClipRect(
                          child: Padding(
                            padding: _pagePadding,
                            child: Align(
                              alignment: Alignment.topLeft,
                              child: _PageText(
                                page: state.currentPage,
                                highlightOffset: state.highlightOffset,
                                style: textStyle,
                                highlightColor: palette.accent,
                                onWordLongPress: onWordLongPress,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
          _NormalBottomBar(
            l10n: l10n,
            progress: state.progress,
            palette: palette,
            modeLocked: modeLocked,
            onToggleModeLock: onToggleModeLock,
            onOpenMenu: onOpenMenu,
          ),
        ],
      ),
    );
  }
}

class _NormalBottomBar extends StatelessWidget {
  const _NormalBottomBar({
    required this.l10n,
    required this.progress,
    required this.palette,
    required this.modeLocked,
    required this.onToggleModeLock,
    required this.onOpenMenu,
  });

  final AppLocalizations l10n;
  final ReaderProgress progress;
  final ReaderPalette palette;
  final bool modeLocked;
  final VoidCallback onToggleModeLock;
  final VoidCallback onOpenMenu;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        child: Row(
          children: <Widget>[
            IconButton(
              tooltip: l10n.readerModeLock,
              color: palette.text,
              icon: Icon(modeLocked ? Icons.lock : Icons.lock_open_outlined),
              onPressed: onToggleModeLock,
            ),
            Expanded(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  LinearProgressIndicator(
                    // Value must stay a plain number for the platform a11y
                    // progress role (iOS rejects compound strings).
                    value: (progress.percent / 100).clamp(0.0, 1.0),
                    color: palette.accent,
                    backgroundColor: palette.dim.withValues(alpha: 0.24),
                    semanticsLabel: l10n.readerProgressLabel,
                    semanticsValue: '${progress.percent.round()}%',
                  ),
                  const SizedBox(height: 4),
                  // Page count carries its own clean a11y label; the raw
                  // "%  ·  n / m" string is excluded to avoid double reads.
                  Semantics(
                    label: l10n.readerPageOf(
                        progress.pageIndex + 1, progress.pageCount),
                    child: ExcludeSemantics(
                      child: Text(
                        '${progress.percent.round()}%   ·   '
                        '${progress.pageIndex + 1} / ${progress.pageCount}',
                        style: theme.textTheme.bodySmall
                            ?.copyWith(color: palette.dim),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            IconButton(
              tooltip: l10n.readerMenu,
              color: palette.text,
              icon: const Icon(Icons.more_vert),
              onPressed: onOpenMenu,
            ),
          ],
        ),
      ),
    );
  }
}

/// Page body rendered word-by-word so the resume marker (from a fast-mode
/// handoff or a long-press) can be underlined, and any word long-pressed to
/// report its source offset ("continue reading from here").
class _PageText extends StatefulWidget {
  const _PageText({
    required this.page,
    required this.highlightOffset,
    required this.style,
    required this.highlightColor,
    required this.onWordLongPress,
  });

  final ReaderPage page;
  final int? highlightOffset;
  final TextStyle style;
  final Color highlightColor;
  final void Function(int offset) onWordLongPress;

  @override
  State<_PageText> createState() => _PageTextState();
}

class _PageTextState extends State<_PageText>
    with SingleTickerProviderStateMixin {
  static final RegExp _word = RegExp(r'\S+');
  final List<LongPressGestureRecognizer> _recognizers =
      <LongPressGestureRecognizer>[];

  /// Selection pop: a brief background flash behind the newly marked word so
  /// picking a resume point is clearly noticeable.
  late final AnimationController _flash = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 550),
  );

  @override
  void didUpdateWidget(_PageText old) {
    super.didUpdateWidget(old);
    if (widget.highlightOffset != null &&
        widget.highlightOffset != old.highlightOffset) {
      _flash.forward(from: 0);
    }
  }

  @override
  void dispose() {
    _flash.dispose();
    _disposeRecognizers();
    super.dispose();
  }

  void _disposeRecognizers() {
    for (final r in _recognizers) {
      r.dispose();
    }
    _recognizers.clear();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _flash,
      builder: (context, _) {
        // Recognizers are per-word and rebuilt each frame; free the old ones
        // first.
        _disposeRecognizers();
        final text = widget.page.text;
        final pageStart = widget.page.startOffset;
        final highlight = widget.highlightOffset;
        // Ease-out fade of the flash (1 -> 0).
        final flashAlpha =
            (1 - Curves.easeOutCubic.transform(_flash.value)) * 0.38;

        final spans = <InlineSpan>[];
        var last = 0;
        for (final m in _word.allMatches(text)) {
          if (m.start > last) {
            spans.add(TextSpan(text: text.substring(last, m.start)));
          }
          final wordStart = pageStart + m.start;
          final wordEnd = pageStart + m.end;
          final isMarked = highlight != null &&
              highlight >= wordStart &&
              highlight < wordEnd;
          final recognizer = LongPressGestureRecognizer()
            ..onLongPress = () => widget.onWordLongPress(wordStart);
          _recognizers.add(recognizer);
          spans.add(TextSpan(
            text: m.group(0),
            recognizer: recognizer,
            style: isMarked
                ? widget.style.copyWith(
                    decoration: TextDecoration.underline,
                    decorationColor: widget.highlightColor,
                    decorationThickness: 2.5,
                    backgroundColor: flashAlpha <= 0.01
                        ? null
                        : widget.highlightColor
                            .withValues(alpha: flashAlpha),
                  )
                : null,
          ));
          last = m.end;
        }
        if (last < text.length) {
          spans.add(TextSpan(text: text.substring(last)));
        }

        return Text.rich(TextSpan(style: widget.style, children: spans));
      },
    );
  }
}
