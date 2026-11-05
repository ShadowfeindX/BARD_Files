import 'package:backend/backend.dart';
import 'package:flutter_test/flutter_test.dart';

import 'firestore_test_support.dart';

const _root = 'projects/proj/databases/(default)/documents';

Map<String, Object?> _doc(String path, Map<String, Object?> fields) => {
  'name': '$_root/$path',
  'fields': fields,
  'createTime': '2026-11-05T09:00:00.000000Z',
  'updateTime': '2026-11-05T09:01:00.123456789Z',
};

FirestoreClient _client(
  FakeTransport transport,
  CountingTokens tokens, [
  List<Duration>? delays,
]) => FirestoreClient(
  projectId: 'proj',
  tokenProvider: tokens,
  transport: transport,
  delay: (d) async => delays?.add(d),
);

void main() {
  _extra();
  test('getDocument decodes fields and sends a fresh Bearer token', () async {
    final transport = FakeTransport([
      json(
        200,
        _doc('things/a', {
          'n': {'integerValue': '3'},
        }),
      ),
    ]);
    final tokens = CountingTokens();
    final doc = await _client(transport, tokens).getDocument('things/a');
    expect(doc!.path, 'things/a');
    expect(doc.id, 'a');
    expect(doc.data, {'n': 3});
    expect(doc.updateTime, DateTime.utc(2026, 11, 5, 9, 1, 0, 123, 456));
    expect(transport.seen.single.method, 'GET');
    expect(
      transport.seen.single.uri.toString(),
      'https://firestore.googleapis.com/v1/$_root/things/a',
    );
    expect(transport.seen.single.headers['Authorization'], 'Bearer t1');
  });

  test('every request asks for a token; none is cached', () async {
    final transport = FakeTransport([
      json(200, _doc('a/1', {})),
      json(200, _doc('a/2', {})),
    ]);
    final tokens = CountingTokens();
    final client = _client(transport, tokens);
    await client.getDocument('a/1');
    await client.getDocument('a/2');
    expect(tokens.calls, [false, false]);
    expect(transport.seen[1].headers['Authorization'], 'Bearer t2');
  });

  test('signed-out sends no Authorization header', () async {
    final transport = FakeTransport([json(200, _doc('a/1', {}))]);
    await _client(
      transport,
      CountingTokens(signedIn: false),
    ).getDocument('a/1');
    expect(transport.seen.single.headers.containsKey('Authorization'), isFalse);
  });

  test('getDocument returns null on 404', () async {
    final transport = FakeTransport([
      json(404, errorBody(404, 'NOT_FOUND', 'Document not found')),
    ]);
    expect(
      await _client(transport, CountingTokens()).getDocument('a/1'),
      isNull,
    );
  });

  test('401 refreshes the token once and retries', () async {
    final transport = FakeTransport([
      json(401, errorBody(401, 'UNAUTHENTICATED', 'expired')),
      json(200, _doc('a/1', {})),
    ]);
    final tokens = CountingTokens();
    await _client(transport, tokens).getDocument('a/1');
    expect(tokens.calls, [false, true]);
    expect(transport.seen[1].headers['Authorization'], 'Bearer t2');
  });

  test('a second 401 surfaces as unauthenticated', () async {
    final transport = FakeTransport([
      json(401, errorBody(401, 'UNAUTHENTICATED', 'expired')),
      json(401, errorBody(401, 'UNAUTHENTICATED', 'expired')),
    ]);
    await expectLater(
      _client(transport, CountingTokens()).getDocument('a/1'),
      throwsA(
        isA<FirestoreException>().having(
          (e) => e.kind,
          'kind',
          FirestoreErrorKind.unauthenticated,
        ),
      ),
    );
    expect(transport.seen, hasLength(2));
  });

  test('403 is not retried', () async {
    final transport = FakeTransport([
      json(403, errorBody(403, 'PERMISSION_DENIED', 'no')),
    ]);
    await expectLater(
      _client(transport, CountingTokens()).getDocument('a/1'),
      throwsA(
        isA<FirestoreException>().having(
          (e) => e.kind,
          'kind',
          FirestoreErrorKind.permissionDenied,
        ),
      ),
    );
    expect(transport.seen, hasLength(1));
  });

  test('503 and network errors back off exponentially, then succeed', () async {
    final transport = FakeTransport([
      json(503, errorBody(503, 'UNAVAILABLE', 'try later')),
      const FirestoreTransportException('reset'),
      json(200, _doc('a/1', {})),
    ]);
    final delays = <Duration>[];
    await _client(transport, CountingTokens(), delays).getDocument('a/1');
    expect(delays, [
      const Duration(milliseconds: 200),
      const Duration(milliseconds: 400),
    ]);
  });

  test('gives up after maxAttempts', () async {
    final transport = FakeTransport([
      for (var i = 0; i < 4; i++)
        json(503, errorBody(503, 'UNAVAILABLE', 'down')),
    ]);
    await expectLater(
      _client(transport, CountingTokens()).getDocument('a/1'),
      throwsA(isA<FirestoreException>()),
    );
    expect(transport.seen, hasLength(4));
  });

  test('addDocument (server id) is not retried on 503', () async {
    final transport = FakeTransport([
      json(503, errorBody(503, 'UNAVAILABLE', 'down')),
    ]);
    await expectLater(
      _client(transport, CountingTokens()).addDocument('a', {'x': 1}),
      throwsA(isA<FirestoreException>()),
    );
    expect(transport.seen, hasLength(1));
  });

  test('createDocument posts documentId under the parent', () async {
    final transport = FakeTransport([json(200, _doc('a/1/b/2', {}))]);
    await _client(
      transport,
      CountingTokens(),
    ).createDocument('a/1/b/2', {'s': 'v'});
    final r = transport.seen.single;
    expect(r.method, 'POST');
    expect(r.uri.path, '/v1/$_root/a/1/b');
    expect(r.uri.queryParameters, {'documentId': '2'});
    expect(r.body, {
      'fields': {
        's': {'stringValue': 'v'},
      },
    });
  });

  test('setDocument replaces; patchDocument masks fields', () async {
    final transport = FakeTransport([
      json(200, _doc('a/1', {})),
      json(200, _doc('a/1', {})),
    ]);
    final client = _client(transport, CountingTokens());
    await client.setDocument('a/1', {'x': 1}, mustExist: false);
    await client.patchDocument(
      'a/1',
      {'x': 1},
      fieldPaths: ['x', 'meta.some key'],
      ifUpdateTime: DateTime.utc(2026, 1, 1),
    );
    expect(transport.seen[0].method, 'PATCH');
    expect(transport.seen[0].uri.query, 'currentDocument.exists=false');
    expect(transport.seen[1].uri.queryParametersAll['updateMask.fieldPaths'], [
      'x',
      'meta.`some key`',
    ]);
    expect(
      transport.seen[1].uri.queryParameters['currentDocument.updateTime'],
      '2026-01-01T00:00:00.000Z',
    );
  });

  test('deleteDocument tolerates an empty body', () async {
    final transport = FakeTransport([json(200, <String, Object?>{})]);
    await _client(transport, CountingTokens()).deleteDocument('a/1');
    expect(transport.seen.single.method, 'DELETE');
  });

  test(
    'runQuery encodes the query and skips result rows without a document',
    () async {
      final transport = FakeTransport([
        json(200, [
          {'readTime': '2026-11-05T09:00:00Z'},
          {
            'document': _doc('c/1', {
              'n': {'integerValue': '5'},
            }),
            'readTime': '2026-11-05T09:00:00Z',
          },
        ]),
      ]);
      final docs = await _client(transport, CountingTokens()).runQuery(
        const FirestoreQuery(
          'c',
          where: AndFilter([
            FieldFilter('n', FilterOp.greaterThanOrEqual, 2),
            FieldFilter('gone', FilterOp.equal, null),
          ]),
          orderBy: [QueryOrder('n', descending: true)],
          limit: 2,
        ),
      );
      expect(docs.single.data, {'n': 5});
      final r = transport.seen.single;
      expect(r.uri.path, '/v1/$_root:runQuery');
      expect(r.body, {
        'structuredQuery': {
          'from': [
            {'collectionId': 'c', 'allDescendants': false},
          ],
          'where': {
            'compositeFilter': {
              'op': 'AND',
              'filters': [
                {
                  'fieldFilter': {
                    'field': {'fieldPath': 'n'},
                    'op': 'GREATER_THAN_OR_EQUAL',
                    'value': {'integerValue': '2'},
                  },
                },
                {
                  'unaryFilter': {
                    'op': 'IS_NULL',
                    'field': {'fieldPath': 'gone'},
                  },
                },
              ],
            },
          },
          'orderBy': [
            {
              'field': {'fieldPath': 'n'},
              'direction': 'DESCENDING',
            },
          ],
          'limit': 2,
        },
      });
    },
  );

  test('runQuery under a document parent', () async {
    final transport = FakeTransport([json(200, <Object?>[])]);
    await _client(
      transport,
      CountingTokens(),
    ).runQuery(const FirestoreQuery('b'), parentPath: 'a/1');
    expect(transport.seen.single.uri.path, '/v1/$_root/a/1:runQuery');
  });

  test('missing index error carries the console link', () async {
    final transport = FakeTransport([
      json(400, [
        errorBody(
          400,
          'FAILED_PRECONDITION',
          'The query requires an index. You can create it here: https://console.firebase.google.com/x?create_composite=abc',
        ),
      ]),
    ]);
    await expectLater(
      _client(transport, CountingTokens()).runQuery(const FirestoreQuery('c')),
      throwsA(
        isA<FirestoreException>()
            .having((e) => e.kind, 'kind', FirestoreErrorKind.missingIndex)
            .having(
              (e) => e.indexUrl,
              'indexUrl',
              'https://console.firebase.google.com/x?create_composite=abc',
            ),
      ),
    );
    expect(transport.seen, hasLength(1));
  });

  test('path validation', () async {
    final client = _client(FakeTransport([]), CountingTokens());
    expect(() => client.getDocument('a'), throwsArgumentError);
    expect(() => client.getDocument('a//b'), throwsArgumentError);
    expect(() => client.addDocument('a/b', {}), throwsArgumentError);
    expect(
      () => client.setDocument(
        'a/b',
        {},
        mustExist: true,
        ifUpdateTime: DateTime.now(),
      ),
      throwsArgumentError,
    );
  });
}

void _extra() {
  test('empty fieldPaths is refused', () async {
    final client = _client(FakeTransport([]), CountingTokens());
    await expectLater(
      client.patchDocument('a/1', {}, fieldPaths: []),
      throwsArgumentError,
    );
  });

  test('parent segments are URL-encoded on create', () async {
    final transport = FakeTransport([
      json(200, _doc('a/x y/b/z', {})),
      json(200, _doc('a/x y/b/z', {})),
    ]);
    final client = _client(transport, CountingTokens());
    await client.createDocument('a/x#y/b/z', {});
    await client.addDocument('a/x#y/b', {});
    expect(transport.seen[0].uri.path, '/v1/$_root/a/x%23y/b');
    expect(transport.seen[1].uri.path, '/v1/$_root/a/x%23y/b');
  });

  test('ABORTED maps to aborted, not alreadyExists', () {
    final e = FirestoreException.fromResponse(409, {
      'status': 'ABORTED',
      'message': 'contention',
    });
    expect(e.kind, FirestoreErrorKind.aborted);
    expect(
      FirestoreException.fromResponse(409, null).kind,
      FirestoreErrorKind.alreadyExists,
    );
  });

  test('cursor inclusivity follows the SDK meaning', () async {
    final transport = FakeTransport([json(200, <Object?>[])]);
    await _client(transport, CountingTokens()).runQuery(
      const FirestoreQuery(
        'c',
        orderBy: [QueryOrder('n')],
        startAt: QueryCursor([1]),
        endAt: QueryCursor([5]),
      ),
    );
    final q = transport.seen.single.body!['structuredQuery']! as Map;
    expect((q['startAt']! as Map)['before'], true);
    expect((q['endAt']! as Map)['before'], false);
  });
}
