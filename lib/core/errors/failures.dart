/// Base type for typed, user-safe failures returned by repositories.
///
/// Repositories return [Failure] subtypes (wrapped in `Result`) instead of
/// throwing, so the UI/state layer can handle errors exhaustively.
sealed class Failure {
  const Failure(this.message);

  final String message;

  @override
  String toString() => '$runtimeType: $message';
}

final class UnknownFailure extends Failure {
  const UnknownFailure([super.message = 'Something went wrong.']);
}

final class NetworkFailure extends Failure {
  const NetworkFailure([super.message = 'Network error.']);
}

final class NotFoundFailure extends Failure {
  const NotFoundFailure([super.message = 'Not found.']);
}

final class UnauthorizedFailure extends Failure {
  const UnauthorizedFailure([super.message = 'Not authorized.']);
}

final class ValidationFailure extends Failure {
  const ValidationFailure([super.message = 'Validation failed.']);
}

final class StorageFailure extends Failure {
  const StorageFailure([super.message = 'Storage error.']);
}

/// Returned when an operation needs the backend (Supabase) but it is not
/// configured for this build — e.g. running in dev without keys.
final class BackendUnavailableFailure extends Failure {
  const BackendUnavailableFailure([super.message = 'Backend is not configured.']);
}
