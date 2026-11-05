/// The kind of failure behind a [FirestoreException].
enum FirestoreErrorKind {
  /// 401 / `UNAUTHENTICATED`: missing, invalid or expired token.
  unauthenticated,

  /// 403 / `PERMISSION_DENIED`: Security Rules refused the request.
  permissionDenied,

  /// 404 / `NOT_FOUND`: the document does not exist.
  notFound,

  /// 409 / `ALREADY_EXISTS`: a create hit an existing document.
  alreadyExists,

  /// 400 / `FAILED_PRECONDITION` saying the query needs a composite index.
  /// [FirestoreException.indexUrl] holds the console link when one was sent.
  missingIndex,

  /// `FAILED_PRECONDITION` for any other precondition (for example a failed
  /// `updateTime` check). The exact status of a failed `exists` check is not
  /// verified against a live server.
  failedPrecondition,

  /// 400 / `INVALID_ARGUMENT`: the request was malformed.
  invalidArgument,

  /// 409 / `ABORTED`: contention; the caller may retry the whole operation.
  aborted,

  /// 429 / `RESOURCE_EXHAUSTED`: quota or rate limit.
  resourceExhausted,

  /// 503 / `UNAVAILABLE`, 504 / `DEADLINE_EXCEEDED`, 500 / `INTERNAL`, or the
  /// network failing before a response arrived.
  unavailable,

  /// Anything else.
  unknown,
}

/// A failed Firestore REST call, mapped from the HTTP status and the error
/// body.
class FirestoreException implements Exception {
  /// Creates an exception.
  const FirestoreException({
    required this.kind,
    required this.message,
    this.httpStatus,
    this.status,
    this.indexUrl,
  });

  /// The mapped failure kind.
  final FirestoreErrorKind kind;

  /// Human-readable message from the server or the transport.
  final String message;

  /// The HTTP status code, or `null` when no response arrived.
  final int? httpStatus;

  /// The Google RPC status string (`PERMISSION_DENIED`, ...), when sent.
  final String? status;

  /// For [FirestoreErrorKind.missingIndex]: the link that creates the index.
  final String? indexUrl;

  /// Builds an exception from an HTTP [httpStatus] and the decoded error
  /// object (`{"code":..,"message":..,"status":..}`), which may be `null`.
  factory FirestoreException.fromResponse(
    int httpStatus,
    Map<String, Object?>? error,
  ) {
    final status = error?['status'] is String
        ? error!['status']! as String
        : null;
    final message =
        (error?['message'] is String ? error!['message']! as String : null) ??
        'HTTP $httpStatus';
    String? indexUrl;
    var kind = _kindFor(httpStatus, status);
    if (kind == FirestoreErrorKind.failedPrecondition &&
        message.contains('requires an index')) {
      kind = FirestoreErrorKind.missingIndex;
      indexUrl = RegExp(r'https://\S+')
          .firstMatch(message)
          ?.group(0)
          ?.replaceFirst(RegExp(r'[.,;)]+$'), '');
    }
    return FirestoreException(
      kind: kind,
      message: message,
      httpStatus: httpStatus,
      status: status,
      indexUrl: indexUrl,
    );
  }

  static FirestoreErrorKind _kindFor(int httpStatus, String? status) {
    switch (status) {
      case 'UNAUTHENTICATED':
        return FirestoreErrorKind.unauthenticated;
      case 'PERMISSION_DENIED':
        return FirestoreErrorKind.permissionDenied;
      case 'NOT_FOUND':
        return FirestoreErrorKind.notFound;
      case 'ALREADY_EXISTS':
        return FirestoreErrorKind.alreadyExists;
      case 'FAILED_PRECONDITION':
        return FirestoreErrorKind.failedPrecondition;
      case 'ABORTED':
        return FirestoreErrorKind.aborted;
      case 'INVALID_ARGUMENT':
        return FirestoreErrorKind.invalidArgument;
      case 'RESOURCE_EXHAUSTED':
        return FirestoreErrorKind.resourceExhausted;
      case 'UNAVAILABLE':
      case 'DEADLINE_EXCEEDED':
      case 'INTERNAL':
        return FirestoreErrorKind.unavailable;
    }
    // No (known) status string: fall back on the HTTP status.
    switch (httpStatus) {
      case 401:
        return FirestoreErrorKind.unauthenticated;
      case 403:
        return FirestoreErrorKind.permissionDenied;
      case 404:
        return FirestoreErrorKind.notFound;
      case 409:
        return FirestoreErrorKind.alreadyExists;
      case 400:
        return FirestoreErrorKind.invalidArgument;
      case 429:
        return FirestoreErrorKind.resourceExhausted;
      case 500:
      case 503:
      case 504:
        return FirestoreErrorKind.unavailable;
    }
    return FirestoreErrorKind.unknown;
  }

  @override
  String toString() =>
      'FirestoreException(${kind.name}, http $httpStatus, $message)';
}
