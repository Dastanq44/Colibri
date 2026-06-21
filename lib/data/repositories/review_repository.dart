import '../../core/result/result.dart';

/// Boundary for public reviews/ratings (moderated). Optional for MVP;
/// implemented in Phase 13. Only approved reviews are exposed publicly.
abstract interface class ReviewRepository {
  Future<Result<void>> submitReview(
    String bookId, {
    required int rating,
    String? title,
    String? body,
  });

  Future<Result<void>> getApprovedReviews(String bookId);

  Future<Result<void>> reportReview(String reviewId, {required String reason});
}
