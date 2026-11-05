import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:backend/firestore_io.dart';
import 'package:backend/backend.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('sends method, headers and body; returns status and text', () async {
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    addTearDown(() => server.close(force: true));
    server.listen((req) async {
      final body = await utf8.decodeStream(req);
      req.response
        ..statusCode = 201
        ..write('${req.method} ${req.headers.value('authorization')} $body');
      await req.response.close();
    });
    final transport = IoFirestoreTransport();
    addTearDown(transport.close);
    final response = await transport.send(
      method: 'PATCH',
      uri: Uri.parse('http://127.0.0.1:${server.port}/x'),
      headers: {'Authorization': 'Bearer t'},
      body: Uint8List.fromList(utf8.encode('{"a":1}')),
    );
    expect(response.statusCode, 201);
    expect(response.body, 'PATCH Bearer t {"a":1}');
  });

  test('a refused connection becomes FirestoreTransportException', () async {
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    final port = server.port;
    await server.close();
    final transport = IoFirestoreTransport();
    addTearDown(transport.close);
    await expectLater(
      transport.send(
        method: 'GET',
        uri: Uri.parse('http://127.0.0.1:$port/'),
        headers: const {},
      ),
      throwsA(isA<FirestoreTransportException>()),
    );
  });
}
