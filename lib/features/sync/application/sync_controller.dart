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
    if (state is SyncRunning) return;
    state = const SyncRunning();
    final result = await ref.read(syncRepositoryProvider).syncNow();
    state = result.when(
      ok: (run) => SyncSuccess(run),
      err: SyncFailure.new,
    );
    ref.invalidate(pendingSyncCountProvider);
  }
}

final syncControllerProvider =
    NotifierProvider<SyncController, SyncUiState>(SyncController.new);
