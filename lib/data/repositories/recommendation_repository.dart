import '../../core/result/result.dart';

/// Boundary for rule-based (non-ML) recommendation rails. Implemented in
/// Phase 14. Every rail must be explainable (carry a human-readable reason).
abstract interface class RecommendationRepository {
  Future<Result<void>> getHomeRecommendationRails();

  Future<Result<void>> getSimilarBooks(String bookId);

  Future<Result<void>> getGoodForFastMode();

  Future<Result<void>> getReturnToAbandoned();
}
