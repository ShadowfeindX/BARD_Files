import 'dart:typed_data';

/// One HTTP response, reduced to what the Firestore client needs.
class FirestoreHttpResponse {
  /// Creates a response.
  const FirestoreHttpResponse(this.statusCode, this.body);

  /// The HTTP status code.
  final int statusCode;

  /// The response body decoded as UTF-8 text (may be empty).
  final String body;

  /// Whether the status is 2xx.
  bool get isSuccess => statusCode >= 200 && statusCode < 300;
}

/// The network seam under the Firestore client.
///
/// The default `dart:io` implementation lives in `package:backend/firestore_io.dart`
/// so this library stays importable on the web. Tests supply a fake.
abstract interface class FirestoreTransport {
  /// Sends one request and returns the response for any HTTP status.
  ///
  /// Throws [FirestoreTransportException] when no response arrived (DNS,
  /// connection reset, timeout).
  Future<FirestoreHttpResponse> send({
    required String method,
    required Uri uri,
    required Map<String, String> headers,
    Uint8List? body,
  });
}

/// The network failed before any response arrived.
class FirestoreTransportException implements Exception {
  /// Creates the exception.
  const FirestoreTransportException(this.message);

  /// What went wrong.
  final String message;

  @override
  String toString() => 'FirestoreTransportException($message)';
}
