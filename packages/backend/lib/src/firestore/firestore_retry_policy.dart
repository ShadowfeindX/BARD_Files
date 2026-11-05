import 'dart:math';

import 'firestore_exception.dart';

/// What the client does after a failed attempt.
sealed class RetryDecision {
  const RetryDecision();
}

/// Give up and throw the error.
class GiveUp extends RetryDecision {
  /// Creates the decision.
  const GiveUp();
}

/// Wait [delay], then send again with the same kind of token call.
class RetryAfter extends RetryDecision {
  /// Creates the decision.
  const RetryAfter(this.delay);

  /// How long to wait first.
  final Duration delay;
}

/// Send again at once after asking the provider for a fresh token
/// (`getIdToken(forceRefresh: true)`).
class RefreshTokenAndRetry extends RetryDecision {
  /// Creates the decision.
  const RefreshTokenAndRetry();
}

/// Decides how the client reacts to a failed attempt (06-O1).
///
/// Pluggable: R's final ruling on 06-O1 only needs a different subclass.
abstract interface class FirestoreRetryPolicy {
  /// Decides after attempt number [attempt] (1 for the first try) failed with
  /// [error]. [idempotent] is `false` for a create without a caller-chosen
  /// id. [tokenAlreadyRefreshed] is `true` once this call has forced a token
  /// refresh.
  RetryDecision decide({
    required FirestoreException error,
    required int attempt,
    required bool idempotent,
    required bool tokenAlreadyRefreshed,
  });
}

/// The proposed 06-O1 behavior: on 401 refresh the token and retry once; on a
/// transient failure back off exponentially (idempotent calls only); give up
/// on everything else, including a missing index and `PERMISSION_DENIED`.
class DefaultFirestoreRetryPolicy implements FirestoreRetryPolicy {
  /// Creates the policy.
  const DefaultFirestoreRetryPolicy({
    this.maxAttempts = 4,
    this.baseDelay = const Duration(milliseconds: 200),
    this.maxDelay = const Duration(seconds: 5),
  });

  /// Total tries allowed, including the first.
  final int maxAttempts;

  /// Delay before the first transient retry; doubles each time.
  final Duration baseDelay;

  /// Upper bound for one delay.
  final Duration maxDelay;

  @override
  RetryDecision decide({
    required FirestoreException error,
    required int attempt,
    required bool idempotent,
    required bool tokenAlreadyRefreshed,
  }) {
    switch (error.kind) {
      case FirestoreErrorKind.unauthenticated:
        return tokenAlreadyRefreshed
            ? const GiveUp()
            : const RefreshTokenAndRetry();
      case FirestoreErrorKind.unavailable:
      case FirestoreErrorKind.resourceExhausted:
        if (!idempotent || attempt >= maxAttempts) return const GiveUp();
        final millis = min(
          maxDelay.inMilliseconds,
          baseDelay.inMilliseconds * pow(2, attempt - 1).toInt(),
        );
        return RetryAfter(Duration(milliseconds: millis));
      default:
        return const GiveUp();
    }
  }
}
