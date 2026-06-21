import '../../core/result/result.dart';

/// Boundary for reading progress (save/restore). Implemented in Phase 7 and
/// synced in Phase 12. Progress is the highest-risk data in the product, so it
/// is saved locally first and reconciled with the cloud separately.
abstract interface class ProgressRepository {
  /// Persists the latest reading position for [bookId].
  // TODO(phase7): accept a typed ReaderLocator / ReaderProgress.
  Future<Result<void>> saveProgress(String bookId);

  Future<Result<void>> loadProgress(String bookId);
}
