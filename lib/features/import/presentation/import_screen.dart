import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/localization/generated/app_localizations.dart';
import '../../../app/router/app_routes.dart';
import '../../../app/widgets/glass_buttons.dart';
import '../../../core/errors/failures.dart';
import '../application/import_controller.dart';
import '../domain/book_import_status.dart';

/// Local-first book import screen: pick a file, see progress, then open the
/// reader or jump to My Books.
class ImportScreen extends ConsumerWidget {
  const ImportScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final state = ref.watch(importControllerProvider);
    final controller = ref.read(importControllerProvider.notifier);

    return Scaffold(
      appBar: AppBar(
        leading: const GlassBackButton(),
        title: Text(l10n.importTitle),
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: switch (state) {
            ImportRunning(:final status) => _Running(l10n: l10n, status: status),
            ImportSuccess(:final book) => _Success(
                l10n: l10n,
                title: book.title,
                onOpenReader: () => context.push(AppRoutes.reader(book.bookId)),
                onGoToLibrary: () => context.go(AppRoutes.library),
                onImportAnother: controller.reset,
              ),
            ImportError(:final failure) => _ErrorView(
                l10n: l10n,
                message: _failureMessage(l10n, failure),
                onRetry: controller.pickAndImport,
              ),
            ImportIdle() => _Idle(l10n: l10n, onChoose: controller.pickAndImport),
          },
        ),
      ),
    );
  }

  String _failureMessage(AppLocalizations l10n, Failure failure) =>
      switch (failure) {
        UnsupportedFormatFailure() => l10n.importErrorUnsupported,
        FileTooLargeFailure() => l10n.importErrorTooLarge,
        FileMissingFailure() => l10n.importErrorMissing,
        DuplicateFailure() => l10n.importErrorDuplicate,
        EmptyBookFailure() => l10n.readerEmpty,
        _ => l10n.importErrorGeneric,
      };
}

class _Idle extends StatelessWidget {
  const _Idle({required this.l10n, required this.onChoose});

  final AppLocalizations l10n;
  final VoidCallback onChoose;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        Icon(CupertinoIcons.square_arrow_up,
            size: 72, color: theme.colorScheme.primary),
        const SizedBox(height: 16),
        Text(
          l10n.importSupportedFormats,
          textAlign: TextAlign.center,
          style: theme.textTheme.bodyMedium
              ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
        ),
        const SizedBox(height: 24),
        FilledButton.icon(
          onPressed: onChoose,
          icon: const Icon(CupertinoIcons.folder),
          label: Text(l10n.importChooseFile),
        ),
      ],
    );
  }
}

class _Running extends StatelessWidget {
  const _Running({required this.l10n, required this.status});

  final AppLocalizations l10n;
  final BookImportStatus status;

  @override
  Widget build(BuildContext context) {
    final label = switch (status) {
      BookImportStatus.validating => l10n.importValidating,
      BookImportStatus.savingLocal ||
      BookImportStatus.copying ||
      BookImportStatus.extractingMetadata =>
        l10n.importSaving,
      _ => l10n.importWorking,
    };
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        const CupertinoActivityIndicator(radius: 14),
        const SizedBox(height: 16),
        Text(label),
      ],
    );
  }
}

class _Success extends StatelessWidget {
  const _Success({
    required this.l10n,
    required this.title,
    required this.onOpenReader,
    required this.onGoToLibrary,
    required this.onImportAnother,
  });

  final AppLocalizations l10n;
  final String title;
  final VoidCallback onOpenReader;
  final VoidCallback onGoToLibrary;
  final VoidCallback onImportAnother;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        Icon(CupertinoIcons.check_mark_circled,
            size: 72, color: theme.colorScheme.primary),
        const SizedBox(height: 16),
        Text(l10n.importSuccessTitle, style: theme.textTheme.titleMedium),
        const SizedBox(height: 4),
        Text(title,
            textAlign: TextAlign.center, style: theme.textTheme.titleLarge),
        const SizedBox(height: 24),
        FilledButton.icon(
          onPressed: onOpenReader,
          icon: const Icon(Icons.chrome_reader_mode_outlined),
          label: Text(l10n.importOpenReader),
        ),
        const SizedBox(height: 8),
        OutlinedButton.icon(
          onPressed: onGoToLibrary,
          icon: const Icon(CupertinoIcons.book),
          label: Text(l10n.importGoToLibrary),
        ),
        const SizedBox(height: 8),
        TextButton(onPressed: onImportAnother, child: Text(l10n.importAnother)),
      ],
    );
  }
}

class _ErrorView extends StatelessWidget {
  const _ErrorView({
    required this.l10n,
    required this.message,
    required this.onRetry,
  });

  final AppLocalizations l10n;
  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        Icon(CupertinoIcons.exclamationmark_circle, size: 72, color: theme.colorScheme.error),
        const SizedBox(height: 16),
        Text(l10n.importErrorTitle, style: theme.textTheme.titleMedium),
        const SizedBox(height: 4),
        Text(message, textAlign: TextAlign.center),
        const SizedBox(height: 24),
        FilledButton.icon(
          onPressed: onRetry,
          icon: const Icon(CupertinoIcons.folder),
          label: Text(l10n.importChooseFile),
        ),
      ],
    );
  }
}
