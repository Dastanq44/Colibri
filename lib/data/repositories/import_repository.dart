import '../../core/result/result.dart';

/// Boundary for the book import pipeline (validate → copy → checksum →
/// metadata → local record → optional cloud upload). Implemented in Phase 6.
abstract interface class ImportRepository {
  /// Imports a supported file (`.epub` | `.txt` | `.pdf`) from [filePath]
  /// into app-controlled storage and creates a local book record.
  Future<Result<void>> importFromPath(String filePath);
}
