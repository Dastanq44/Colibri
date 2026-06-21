import '../errors/failures.dart';

/// A minimal success/failure container used as the return type of repository
/// methods. Keeps error handling explicit and exhaustive without throwing.
sealed class Result<T> {
  const Result();

  /// Pattern-matches the result into a single value of type [R].
  R when<R>({
    required R Function(T value) ok,
    required R Function(Failure failure) err,
  }) {
    return switch (this) {
      Ok<T>(:final value) => ok(value),
      Err<T>(:final failure) => err(failure),
    };
  }

  bool get isOk => this is Ok<T>;
  bool get isErr => this is Err<T>;
}

final class Ok<T> extends Result<T> {
  const Ok(this.value);
  final T value;
}

final class Err<T> extends Result<T> {
  const Err(this.failure);
  final Failure failure;
}
