import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/localization/generated/app_localizations.dart';
import '../../../app/theme/reader_theme.dart';
import '../../../core/constants/app_constants.dart';
import '../application/reader_controller.dart';
import '../application/reader_position_policy.dart';
import '../domain/reader_mode.dart';
import '../domain/reader_progress.dart';
import '../fast_mode/application/fast_mode_providers.dart';
import '../fast_mode/presentation/fast_reader_view.dart';
import '../settings/application/reader_settings_providers.dart';
import '../settings/domain/reader_settings.dart';
import '../settings/presentation/reader_settings_sheet.dart';
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

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
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
    }
  }

  bool get _modeLocked =>
      ref.read(readerSettingsProvider).valueOrNull?.modeLockEnabled ?? false;

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
    _handoffPosition(to);
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
      // Seek only when the engine's token is outside the current page; inside
      // it, the engine's finer-grained position wins (no rewind to page start).
      final state = ref.read(readerControllerProvider(widget.bookId));
      if (state is ReaderReady) {
        final page = state.currentPage;
        if (shouldSeekFastEngine(
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
      if (offset != null) reader.jumpToOffset(offset);
    }
  }

  void _toggleModeLock(bool currentlyLocked) {
    final locked = !currentlyLocked;
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
    final choice = await showModalBottomSheet<String>(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            ListTile(
              leading: const Icon(Icons.list_alt_outlined),
              title: Text(l10n.tableOfContents),
              onTap: () => Navigator.pop(ctx, 'toc'),
            ),
            ListTile(
              leading: const Icon(Icons.settings_outlined),
              title: Text(l10n.readerSettingsTitle),
              onTap: () => Navigator.pop(ctx, 'settings'),
            ),
          ],
        ),
      ),
    );
    if (!mounted) return;
    if (choice == 'toc') {
      await showModalBottomSheet<void>(
        context: context,
        builder: (_) => TocSheet(
          toc: state.toc,
          onSelect: (entry) => ref
              .read(readerControllerProvider(widget.bookId).notifier)
              .jumpToChapter(entry),
        ),
      );
    } else if (choice == 'settings') {
      await showModalBottomSheet<void>(
        context: context,
        isScrollControlled: true,
        builder: (_) => const ReaderSettingsSheet(),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
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
          child: const Center(child: CircularProgressIndicator()),
        ),
      ReaderEmpty() => _Scaffold(
          title: l10n.readerTitle,
          child: _Message(icon: Icons.menu_book_outlined, text: l10n.readerEmpty),
        ),
      ReaderUnsupported(:final reason) => _Scaffold(
          title: l10n.readerUnsupportedTitle,
          child: _Message(
            icon: Icons.block_outlined,
            text: _unsupportedText(l10n, reason),
          ),
        ),
      ReaderFailed() => _Scaffold(
          title: l10n.readerTitle,
          child: _Message(icon: Icons.error_outline, text: l10n.readerOpenError),
        ),
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
              onToggleModeLock: () => _toggleModeLock(settings.modeLockEnabled),
              onOpenMenu: () => _openReaderMenu(state),
              onPrevious: ref
                  .read(readerControllerProvider(widget.bookId).notifier)
                  .previousPage,
              onNext: ref
                  .read(readerControllerProvider(widget.bookId).notifier)
                  .nextPage,
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
    required this.onToggleModeLock,
    required this.onOpenMenu,
    required this.onPrevious,
    required this.onNext,
  });

  final AppLocalizations l10n;
  final ReaderReady state;
  final ReaderSettings settings;
  final bool modeLocked;
  final VoidCallback onToggleModeLock;
  final VoidCallback onOpenMenu;
  final VoidCallback onPrevious;
  final VoidCallback onNext;

  @override
  Widget build(BuildContext context) {
    final palette = ReaderPalette.of(settings.theme);
    return Scaffold(
      backgroundColor: palette.background,
      appBar: AppBar(title: Text(state.document.title)),
      body: Column(
        children: <Widget>[
          Expanded(
            // One gesture detector pages by tap half; vertical drags scroll.
            child: LayoutBuilder(
              builder: (context, constraints) {
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
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 24, vertical: 16),
                      child: Text(
                        state.currentPage.text.trim(),
                        style: TextStyle(
                          fontSize: settings.fontSize.toDouble(),
                          height: settings.lineHeight,
                          letterSpacing: settings.letterSpacing,
                          color: palette.text,
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
    required this.modeLocked,
    required this.onToggleModeLock,
    required this.onOpenMenu,
  });

  final AppLocalizations l10n;
  final ReaderProgress progress;
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
              icon: Icon(modeLocked ? Icons.lock : Icons.lock_open_outlined),
              onPressed: onToggleModeLock,
            ),
            Expanded(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  LinearProgressIndicator(
                    value: (progress.percent / 100).clamp(0.0, 1.0),
                  ),
                  const SizedBox(height: 4),
                  Text('${progress.percent.round()}%',
                      style: theme.textTheme.bodySmall),
                ],
              ),
            ),
            IconButton(
              tooltip: l10n.readerMenu,
              icon: const Icon(Icons.more_vert),
              onPressed: onOpenMenu,
            ),
          ],
        ),
      ),
    );
  }
}
