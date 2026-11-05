// Runs the Firestore client against the Firestore emulator.
//
// Skipped unless FIRESTORE_EMULATOR_HOST is set; start it with
// `bash firebase/run_firestore_client_test.sh`. Rules: firebase/firestore.rules.
import 'dart:convert';
import 'dart:io';

import 'package:backend/backend.dart';
import 'package:backend/firestore_io.dart';
import 'package:flutter_test/flutter_test.dart';

/// Builds an unsigned ID token; the emulator accepts it and applies rules.
String _token({String? role}) {
  String part(Map<String, Object?> m) =>
      base64Url.encode(utf8.encode(jsonEncode(m))).replaceAll('=', '');
  return '${part({'alg': 'none', 'typ': 'JWT'})}.'
      '${part({
        'sub': 'u1',
        'user_id': 'u1',
        'firebase': {'sign_in_provider': 'password'},
        'role': ?role,
      })}.';
}

class _Tokens implements IdTokenProvider {
  _Tokens(this.token);
  final String? token;
  @override
  Future<String?> getIdToken({bool forceRefresh = false}) async => token;
}

void main() {
  final host = Platform.environment['FIRESTORE_EMULATOR_HOST'];
  if (host == null) {
    test(
      'Firestore emulator',
      () {},
      skip: 'FIRESTORE_EMULATOR_HOST not set (see firebase/README.md)',
    );
    return;
  }

  final transport = IoFirestoreTransport();
  tearDownAll(transport.close);

  FirestoreClient client(String? token) => FirestoreClient(
    projectId: 'demo-bard',
    host: 'http://$host',
    tokenProvider: _Tokens(token),
    transport: transport,
  );

  final user = client(_token());
  final run = DateTime.now().microsecondsSinceEpoch;
  String id(String n) => 'client_check/${n}_$run';

  test('set, get and decode every type', () async {
    final data = <String, Object?>{
      'n': null,
      'b': true,
      'i': 42,
      'd': 1.5,
      's': 'héllo',
      't': DateTime.utc(2026, 11, 5, 9, 30, 1, 123, 456),
      'r': const FirestoreReference('client_check/other'),
      'g': const FirestoreGeoPoint(1.5, -2.5),
      'a': [1, 'x'],
      'm': {'k': 1},
    };
    await user.setDocument(id('all'), data);
    final doc = await user.getDocument(id('all'));
    expect(doc!.data, data);
    expect(doc.updateTime, isNotNull);
  });

  test('getDocument of a missing document is null', () async {
    expect(await user.getDocument(id('missing')), isNull);
  });

  test('patch changes only the masked fields and can delete one', () async {
    await user.setDocument(id('patch'), {'a': 1, 'b': 2, 'c': 3});
    await user.patchDocument(id('patch'), {'a': 10}, fieldPaths: ['a', 'c']);
    expect((await user.getDocument(id('patch')))!.data, {'a': 10, 'b': 2});
  });

  test('preconditions', () async {
    await user.setDocument(id('pre'), {'v': 1});
    await expectLater(
      user.setDocument(id('pre'), {'v': 2}, mustExist: false),
      throwsA(isA<FirestoreException>()),
    );
    // `currentDocument.updateTime` is not exercised: the emulator reads the
    // query parameter as version 0 and rejects even the exact server value, so
    // the update-time precondition stays unverified against Firestore (it is
    // unit-tested for the request shape only).
    expect((await user.getDocument(id('pre')))!.data, {'v': 1});
  });

  test('create fails when the document exists', () async {
    await user.createDocument(id('create'), {'v': 1});
    await expectLater(
      user.createDocument(id('create'), {'v': 2}),
      throwsA(
        isA<FirestoreException>().having(
          (e) => e.kind,
          'kind',
          FirestoreErrorKind.alreadyExists,
        ),
      ),
    );
  });

  test('addDocument returns a server id', () async {
    final doc = await user.addDocument('client_check', {'v': 1});
    expect(doc.path, startsWith('client_check/'));
    await user.deleteDocument(doc.path);
    expect(await user.getDocument(doc.path), isNull);
  });

  test('runQuery filters, orders and limits', () async {
    final tag = 'q$run';
    for (var n = 1; n <= 5; n++) {
      await user.setDocument('client_check/${tag}_$n', {
        'tag': tag,
        'n': n,
        'list': [n.isEven ? 'even' : 'odd'],
      });
    }
    List<int> ns(List<FirestoreDocument> docs) => [
      for (final d in docs) d.data['n']! as int,
    ];
    final q = FirestoreQuery(
      'client_check',
      where: AndFilter([
        FieldFilter('tag', FilterOp.equal, tag),
        const FieldFilter('n', FilterOp.greaterThanOrEqual, 2),
      ]),
      orderBy: const [QueryOrder('n', descending: true)],
      limit: 3,
    );
    expect(ns(await user.runQuery(q)), [5, 4, 3]);
    expect(
      ns(
        await user.runQuery(
          FirestoreQuery(
            'client_check',
            where: AndFilter([
              FieldFilter('tag', FilterOp.equal, tag),
              const FieldFilter('n', FilterOp.inList, [1, 5]),
            ]),
            orderBy: const [QueryOrder('n')],
          ),
        ),
      ),
      [1, 5],
    );
    expect(
      ns(
        await user.runQuery(
          FirestoreQuery(
            'client_check',
            where: AndFilter([
              FieldFilter('tag', FilterOp.equal, tag),
              const FieldFilter('list', FilterOp.arrayContains, 'even'),
            ]),
            orderBy: const [QueryOrder('n')],
          ),
        ),
      ),
      [2, 4],
    );
    expect(
      ns(
        await user.runQuery(
          FirestoreQuery(
            'client_check',
            where: FieldFilter('tag', FilterOp.equal, tag),
            orderBy: const [QueryOrder('n')],
            startAt: const QueryCursor([2]),
            endAt: const QueryCursor([4]),
          ),
        ),
      ),
      [2, 3, 4],
    );
  });

  test('delete removes the document', () async {
    await user.setDocument(id('del'), {'v': 1});
    await user.deleteDocument(id('del'));
    expect(await user.getDocument(id('del')), isNull);
  });

  test('rules: no token is refused, a claim rule needs the claim', () async {
    await expectLater(
      client(null).getDocument(id('all')),
      throwsA(
        isA<FirestoreException>().having(
          (e) => e.kind,
          'kind',
          FirestoreErrorKind.permissionDenied,
        ),
      ),
    );
    await expectLater(
      user.setDocument('client_check_gm/x_$run', {'v': 1}),
      throwsA(
        isA<FirestoreException>().having(
          (e) => e.kind,
          'kind',
          FirestoreErrorKind.permissionDenied,
        ),
      ),
    );
    final gm = client(_token(role: 'gm'));
    await gm.setDocument('client_check_gm/x_$run', {'v': 1});
    expect((await gm.getDocument('client_check_gm/x_$run'))!.data, {'v': 1});
  });
}
