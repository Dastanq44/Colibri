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

/// The user dismissed/cancelled an interaction (e.g. the file picker). UI
/// should treat this quietly, not as an error.
final class CanceledFailure extends Failure {
  const CanceledFailure([super.message = 'Cancelled.']);
}

/// The selected file extension/type is not supported for import.
final class UnsupportedFormatFailure extends Failure {
  const UnsupportedFormatFailure([super.message = 'Unsupported file type.']);
}

/// The selected file exceeds the maximum allowed import size.
final class FileTooLargeFailure extends Failure {
  const FileTooLargeFailure([super.message = 'File is too large.']);
}

/// The selected file could not be found or read.
final class FileMissingFailure extends Failure {
  const FileMissingFailure([super.message = 'File could not be read.']);
}

/// The book is already present locally (matched by checksum).
final class DuplicateFailure extends Failure {
  const DuplicateFailure([super.message = 'Already imported.']);
}

/// A book file could not be parsed (e.g. malformed EPUB).
final class MalformedBookFailure extends Failure {
  const MalformedBookFailure([super.message = 'Could not read this book.']);
}

/// A book opened but contained no readable text.
final class EmptyBookFailure extends Failure {
  const EmptyBookFailure([super.message = 'No readable text was found.']);
}
