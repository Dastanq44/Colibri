import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/errors/failures.dart';
import '../domain/sync_result.dart';
import 'sync_providers.dart';

/// UI state for the manual sync action.
sealed class SyncUiState {
  const SyncUiState();
}

class SyncIdle extends SyncUiState {
  const SyncIdle();
}

class SyncRunning extends SyncUiState {
  const SyncRunning();
}

class SyncSuccess extends SyncUiState {
  const SyncSuccess(this.result);
  final SyncRunResult result;
}

class SyncFailure extends SyncUiState {
  const SyncFailure(this.failure);
  final Failure failure;
}

class SyncController extends Notifier<SyncUiState> {
  @override
  SyncUiState build() => const SyncIdle();

  Future<void> syncNow() async {
    // This guard also makes the repository's requeue-of-stranded-'processing'
    // rows safe: at most one in-process sync pass runs at a time.
    if (state is SyncRunning) return;
    state = const SyncRunning();
    try {
      // Manual sync (the only trigger today) retries `failed` items so they
      // are never a dead end.
      final result =
          await ref.read(syncRepositoryProvider).syncNow(retryFailed: true);
      state = result.when(
        ok: (run) => SyncSuccess(run),
        err: SyncFailure.new,
      );
    } catch (_) {
      // The repository returns Results, but never let an unexpected throw
      // leave the controller stuck in SyncRunning (which would disable the
      // sync button for the rest of the session).
      state = const SyncFailure(UnknownFailure());
    }
    // No pendingSyncCountProvider invalidation needed: it is a live Drift
    // watch and updates as the queue changes.
  }
}

final syncControllerProvider =
    NotifierProvider<SyncController, SyncUiState>(SyncController.new);
