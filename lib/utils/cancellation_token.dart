/// A simple, reusable cancellation token for cooperative async cancellation.
///
/// Pass this through your service chain so long-running operations can
/// check [isCancelled] and bail early without crashing.
class CancellationToken {
  bool _isCancelled = false;

  /// Whether the token has been cancelled.
  bool get isCancelled => _isCancelled;

  /// Mark this token as cancelled. All downstream checks will see this.
  void cancel() => _isCancelled = true;

  /// Throws [CancelledException] if this token has been cancelled.
  /// Call this at safe checkpoints in your async flow.
  void throwIfCancelled() {
    if (_isCancelled) throw CancelledException();
  }
}

/// Exception thrown when a [CancellationToken] is cancelled.
class CancelledException implements Exception {
  final String message;
  const CancelledException([this.message = 'Operation was cancelled by user.']);

  @override
  String toString() => message;
}
