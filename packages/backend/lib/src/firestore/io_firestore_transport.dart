import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'firestore_transport.dart';

/// [FirestoreTransport] on `dart:io`'s [HttpClient]. Desktop only.
class IoFirestoreTransport implements FirestoreTransport {
  /// Creates a transport. Pass [client] to share one, or to test.
  IoFirestoreTransport({
    HttpClient? client,
    this.timeout = const Duration(seconds: 30),
  }) : _client = client ?? HttpClient();

  final HttpClient _client;

  /// How long one request may take before it counts as a network failure.
  final Duration timeout;

  @override
  Future<FirestoreHttpResponse> send({
    required String method,
    required Uri uri,
    required Map<String, String> headers,
    Uint8List? body,
  }) async {
    try {
      final request = await _client.openUrl(method, uri).timeout(timeout);
      headers.forEach(request.headers.set);
      if (body != null) request.add(body);
      final response = await request.close().timeout(timeout);
      final text = await response
          .transform(utf8.decoder)
          .join()
          .timeout(timeout);
      return FirestoreHttpResponse(response.statusCode, text);
    } on SocketException catch (e) {
      throw FirestoreTransportException(e.message);
    } on HttpException catch (e) {
      throw FirestoreTransportException(e.message);
    } on TlsException catch (e) {
      throw FirestoreTransportException(e.message);
    } on TimeoutException {
      throw const FirestoreTransportException('request timed out');
    }
  }

  /// Closes the underlying client.
  void close() => _client.close(force: true);
}
