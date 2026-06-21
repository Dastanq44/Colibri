import '../../core/result/result.dart';

/// Boundary for book records (catalog + uploaded). Implemented across
/// Phases 5–7. Return payload types (Book / BookDocument) are introduced with
/// the domain models in those phases.
abstract interface class BookRepository {
  Future<Result<void>> getById(String bookId);

  Future<Result<void>> refresh();
}
