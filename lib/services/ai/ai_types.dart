import 'dart:async';

// --- RESULT TYPE FOR BETTER ERROR HANDLING ---
sealed class Result<T> {
  const Result();
  factory Result.ok(T value) = Ok._;
  factory Result.error(Exception error) = ResultError<T>._;

  R when<R>({
    required R Function(T value) ok,
    required R Function(Exception error) error,
  }) {
    if (this is Ok<T>) {
      return ok((this as Ok<T>).value);
    } else {
      return error((this as ResultError<T>).error);
    }
  }
}

final class Ok<T> extends Result<T> {
  const Ok._(this.value);
  final T value;
  @override
  String toString() => 'Result<$T>.ok($value)';
}

final class ResultError<T> extends Result<T> {
  const ResultError._(this.error);
  final Exception error;
  @override
  String toString() => 'Result<$T>.error($error)';
}

// --- EXCEPTIONS ---
class EnhancedAIServiceException implements Exception {
  final String message;
  final String? code;
  final dynamic originalError;

  EnhancedAIServiceException(
    this.message, {
    this.code,
    this.originalError,
  });

  @override
  String toString() => code != null ? '[$code] $message' : message;

  bool get isRateLimitError =>
      code == 'RESOURCE_EXHAUSTED' ||
      code == '429' ||
      message.toLowerCase().contains('rate limit') ||
      message.toLowerCase().contains('quota') ||
      message.toLowerCase().contains('full') ||
      message.toLowerCase().contains('overloaded');

  bool get isNetworkError =>
      code == 'NETWORK_ERROR' || originalError is TimeoutException;
}
