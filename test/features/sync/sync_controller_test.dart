import 'package:colibri/core/errors/failures.dart';
import 'package:colibri/core/result/result.dart';
import 'package:colibri/data/repositories/sync_repository.dart';
import 'package:colibri/features/sync/application/sync_controller.dart';
import 'package:colibri/features/sync/application/sync_providers.dart';
import 'package:colibri/features/sync/domain/remote_progress.dart';
import 'package:colibri/features/sync/domain/sync_result.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

class _FakeSyncRepository implements SyncRepository {
  _FakeSyncRepository(this._syncNow);

  final Future<Result<SyncRunResult>> Function() _syncNow;

  @override
  Future<Result<SyncRunResult>> syncNow({bool retryFailed = false}) =>
      _syncNow();

  @override
  Stream<bool> syncing() => const Stream<bool>.empty();

  @override
  Future<Result<RemoteProgress?>> fetchRemoteProgress(String bookId) async =>
      const Ok(null);
}

ProviderContainer _container(SyncRepository repo) {
  final c = ProviderContainer(
    overrides: <Override>[syncRepositoryProvider.overrideWithValue(repo)],
  );
  addTearDown(c.dispose);
  return c;
}

void main() {
  test('a successful run transitions to SyncSuccess', () async {
    final c = _container(_FakeSyncRepository(() async =>
        const Ok(SyncRunResult(processed: 1, succeeded: 1, failed: 0))));

    await c.read(syncControllerProvider.notifier).syncNow();

    final state = c.read(syncControllerProvider);
    expect(state, isA<SyncSuccess>());
    expect((state as SyncSuccess).result.succeeded, 1);
  });

  test('an Err result transitions to SyncFailure', () async {
    final c = _container(_FakeSyncRepository(
        () async => const Err(BackendUnavailableFailure())));

    await c.read(syncControllerProvider.notifier).syncNow();

    final state = c.read(syncControllerProvider);
    expect(state, isA<SyncFailure>());
    expect((state as SyncFailure).failure, isA<BackendUnavailableFailure>());
  });

  test('an unexpected throw does not leave the controller stuck in SyncRunning',
      () async {
    var shouldThrow = true;
    final c = _container(_FakeSyncRepository(() async {
      if (shouldThrow) throw StateError('boom');
      return const Ok(SyncRunResult(processed: 0, succeeded: 0, failed: 0));
    }));
    final controller = c.read(syncControllerProvider.notifier);

    await controller.syncNow();
    expect(c.read(syncControllerProvider), isA<SyncFailure>());

    // The same controller accepts a new run after the failure (not stuck).
    shouldThrow = false;
    await controller.syncNow();
    expect(c.read(syncControllerProvider), isA<SyncSuccess>());
  });
}
