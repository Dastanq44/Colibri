import '../../core/result/result.dart';

/// Boundary for loading readable book content for the reader engine.
/// Implemented in Phase 7. The reader engine itself never touches data
/// sources directly — it goes through this repository.
abstract interface class ReaderRepository {
  Future<Result<void>> openBook(String bookId);

  // TODO(phase7): return a BookDocument (chapters/text) domain model.
}
