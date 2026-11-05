import 'dart:convert';
import 'dart:typed_data';

import 'package:backend/backend.dart';

/// A request the fake transport saw.
class SeenRequest {
  SeenRequest(this.method, this.uri, this.headers, this.body);
  final String method;
  final Uri uri;
  final Map<String, String> headers;
  final Map<String, Object?>? body;
}

/// Replays scripted responses (a response or an exception) in order.
class FakeTransport implements FirestoreTransport {
  FakeTransport(this.script);
  final List<Object> script;
  final List<SeenRequest> seen = [];

  @override
  Future<FirestoreHttpResponse> send({
    required String method,
    required Uri uri,
    required Map<String, String> headers,
    Uint8List? body,
  }) async {
    seen.add(
      SeenRequest(
        method,
        uri,
        headers,
        body == null
            ? null
            : jsonDecode(utf8.decode(body)) as Map<String, Object?>,
      ),
    );
    final next = script.removeAt(0);
    if (next is FirestoreTransportException) throw next;
    return next as FirestoreHttpResponse;
  }
}

FirestoreHttpResponse json(int status, Object body) =>
    FirestoreHttpResponse(status, jsonEncode(body));

Map<String, Object?> errorBody(int code, String status, String message) => {
  'error': {'code': code, 'status': status, 'message': message},
};

/// Hands out `t1`, `t2`, ... and records each call's `forceRefresh`.
class CountingTokens implements IdTokenProvider {
  CountingTokens({this.signedIn = true});
  final bool signedIn;
  final List<bool> calls = [];

  @override
  Future<String?> getIdToken({bool forceRefresh = false}) async {
    calls.add(forceRefresh);
    return signedIn ? 't${calls.length}' : null;
  }
}
