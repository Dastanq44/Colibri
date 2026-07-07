import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/errors/failures.dart';
import '../../../core/result/result.dart';
import '../../../data/repositories/analytics_repository.dart';
import '../domain/book_import_status.dart';
import '../domain/imported_book.dart';
import 'import_providers.dart';

/// UI-facing state of the import flow.
sealed class ImportState {
  const ImportState();
}

class ImportIdle extends ImportState {
  const ImportIdle();
}

class ImportRunning extends ImportState {
  const ImportRunning(this.status);
  final BookImportStatus status;
}

class ImportSuccess extends ImportState {
  const ImportSuccess(this.book);
  final ImportedBook book;
}

class ImportError extends ImportState {
  const ImportError(this.failure);
  final Failure failure;
}

/// Drives the pick → validate → import pipeline and exposes [ImportState].
class ImportController extends Notifier<ImportState> {
  @override
  ImportState build() => const ImportIdle();

  Future<void> pickAndImport() async {
    final repo = ref.read(importRepositoryProvider);

    state = const ImportRunning(BookImportStatus.selected);
    final preview = switch (await repo.pickBookFile()) {
      Ok(value: final p) => p,
      Err(failure: final f) => _stopWith(f),
    };
    if (preview == null) return;

    // A file was actually picked: the import attempt starts here
    // (TASK-1504). Failure reasons are typed names — never file content.
    final analytics = ref.read(analyticsRepositoryProvider);
    await analytics.logEvent('book_upload_started');

    state = const ImportRunning(BookImportStatus.validating);
    final valid = switch (await repo.validatePickedFile(preview)) {
      Ok(value: final p) => p,
      Err(failure: final f) => _stopWith(f),
    };
    if (valid == null) return;

    state = const ImportRunning(BookImportStatus.savingLocal);
    switch (await repo.importPickedFile(valid)) {
      case Ok(value: final book):
        await analytics
            .logEvent('book_upload_completed', params: {'format': book.format.wire});
        state = ImportSuccess(book);
      case Err(failure: final f):
        await analytics.logEvent('book_upload_failed',
            params: {'reason': f.runtimeType.toString()});
        state = ImportError(f);
    }
  }

  /// Sets idle on cancel, error otherwise; returns null to halt the pipeline.
  Null _stopWith(Failure failure) {
    if (failure is! CanceledFailure) {
      ref.read(analyticsRepositoryProvider).logEvent('book_upload_failed',
          params: {'reason': failure.runtimeType.toString()});
    }
    state = failure is CanceledFailure
        ? const ImportIdle()
        : ImportError(failure);
    return null;
  }

  void reset() => state = const ImportIdle();
}

final importControllerProvider =
    NotifierProvider<ImportController, ImportState>(ImportController.new);
