// RTDB live-play rules checks (P10c), run against the Database emulator's
// REST API. Started from probe 8.6's 116 checks [V-38], with R's P10c
// rulings 1-3, the P23 removal of `phoneDraft`, the post-archive clean-up and
// R's 2026-10-21 rulings (presence closed once archived, `meta` validation,
// no signaling reads or writes and no phone messages for anonymous members,
// plus the review follow-ups: phone message shape, `locked` kept) applied.
// Uses only
// dart:io. Auth is an unsigned JWT, which the emulator accepts.
import 'dart:convert';
import 'dart:io';

/// Emulator host and port; override with the `EMU` environment variable.
final String host = Platform.environment['EMU'] ?? '127.0.0.1:9000';

/// Database namespace of the `demo-bard` emulator project.
const ns = 'demo-bard-default-rtdb';

/// Shared HTTP client for all checks.
final client = HttpClient();

String _b64(Object o) =>
    base64Url.encode(utf8.encode(jsonEncode(o))).replaceAll('=', '');

/// Builds an unsigned ID token for [uid] as the emulator expects it.
String token(String uid, {String provider = 'password'}) {
  final now = DateTime.now().millisecondsSinceEpoch ~/ 1000;
  final header = _b64({'alg': 'none', 'typ': 'JWT'});
  final payload = _b64({
    'iss': 'https://securetoken.google.com/demo-bard',
    'aud': 'demo-bard',
    'sub': uid,
    'user_id': uid,
    'iat': now,
    'exp': now + 3600,
    'firebase': {'sign_in_provider': provider, 'identities': {}},
  });
  return '$header.$payload.';
}

/// Who makes a request: admin (bypasses rules), unauthenticated, or a user.
class Who {
  /// The ID token, `null` for admin, or `'none'` for unauthenticated.
  final String? tok;

  Who._(this.tok);

  /// Admin access, as a function with admin REST would have.
  static Who admin() => Who._(null);

  /// No authentication at all.
  static Who anon() => Who._('none');

  /// A signed-in user with the given sign-in [provider].
  static Who user(String uid, {String provider = 'password'}) =>
      Who._(token(uid, provider: provider));
}

/// Sends one REST request and returns the status code and body.
Future<(int, String)> call(
  String method,
  String path,
  Who who, {
  Object? body,
  Map<String, String> q = const {},
}) async {
  final params = {
    ...q,
    if (who.tok != null && who.tok != 'none') 'auth': who.tok!,
    'ns': ns,
  };
  final req = await client.openUrl(
    method,
    Uri.http(host, '$path.json', params),
  );
  if (who.tok == null) req.headers.set('Authorization', 'Bearer owner');
  if (body != null) {
    req.headers.contentType = ContentType.json;
    req.write(jsonEncode(body));
  }
  final res = await req.close();
  return (res.statusCode, await res.transform(utf8.decoder).join());
}

/// Counts of passed and failed checks.
int pass = 0, fail = 0;

/// One PASS or FAIL line per check, printed at the end.
final lines = <String>[];

/// Records a check that passes when the response has status [code].
Future<void> expectCode(String name, Future<(int, String)> f, int code) async {
  final (c, t) = await f;
  final ok = c == code;
  ok ? pass++ : fail++;
  final detail = ok ? '' : '  body=${t.length > 120 ? t.substring(0, 120) : t}';
  lines.add('${ok ? 'PASS' : 'FAIL'}  $name  (HTTP $c, want $code)$detail');
}

/// Records a check that passes when [test] accepts the response.
Future<void> expectBody(
  String name,
  Future<(int, String)> f,
  bool Function(int, String) test,
) async {
  final (c, t) = await f;
  final ok = test(c, t);
  ok ? pass++ : fail++;
  final shown = t.length > 100 ? t.substring(0, 100) : t;
  lines.add('${ok ? 'PASS' : 'FAIL'}  $name  (HTTP $c, body=$shown)');
}

/// Runs every check in order against a freshly emptied emulator database.
Future<void> main() async {
  final admin = Who.admin();
  final gm = Who.user('gm1');
  final gmAnon = Who.user('anonGm', provider: 'anonymous');
  final p1 = Who.user('p1', provider: 'anonymous'); // anonymous player
  final p2 = Who.user('p2');
  final p4 = Who.user('p4');
  final out = Who.user('out1'); // not a member
  final none = Who.anon();
  const op = 'op1';
  String o(String s) => '/operations/$op/$s';

  await call('DELETE', '/', admin);

  // ---- operation creation ----
  await expectCode(
    'anonymous account cannot create an operation',
    call('PUT', o('meta'), gmAnon, body: {'gm': 'anonGm', 'status': 'active'}),
    401,
  );
  await expectCode(
    'unauthenticated cannot create an operation',
    call('PUT', o('meta'), none, body: {'gm': 'gm1'}),
    401,
  );
  await expectCode(
    'full account cannot name another uid as gm',
    call('PUT', o('meta'), gm, body: {'gm': 'someoneElse'}),
    401,
  );
  await expectCode(
    'full account creates operation as gm',
    call(
      'PUT',
      o('meta'),
      gm,
      body: {'gm': 'gm1', 'status': 'active', 'lastSeq': 0},
    ),
    200,
  );
  await expectCode(
    'other account cannot take over existing operation',
    call('PUT', o('meta'), p2, body: {'gm': 'p2'}),
    401,
  );
  await expectCode(
    'gm cannot reassign gm field',
    call('PUT', o('meta/gm'), gm, body: 'p2'),
    401,
  );
  await expectCode(
    'gm can update lastSeq',
    call('PUT', o('meta/lastSeq'), gm, body: 1),
    200,
  );
  await expectCode(
    'gm can edit status',
    call('PUT', o('meta/status'), gm, body: 'paused'),
    200,
  );
  await expectCode(
    'gm cannot set status archived before lock (admin path only)',
    call('PUT', o('meta/status'), gm, body: 'archived'),
    401,
  );
  await expectCode(
    'gm cannot replace meta with status archived before lock',
    call('PUT', o('meta'), gm, body: {'gm': 'gm1', 'status': 'archived'}),
    401,
  );

  // ---- multi-path PATCH and root PUT, before the lock ----
  // A PATCH on the operation node updates several paths in one write; each
  // changed path is checked and a refusal rolls back the whole write.
  await expectCode(
    'multi-path PATCH: gm updates status and head together (control)',
    call(
      'PATCH',
      '/operations/$op',
      gm,
      body: {
        'meta/status': 'paused',
        'head': {'seq': 1},
      },
    ),
    200,
  );
  await expectCode(
    'multi-path PATCH: status archived with head is refused',
    call(
      'PATCH',
      '/operations/$op',
      gm,
      body: {
        'meta/status': 'archived',
        'head': {'seq': 2},
      },
    ),
    401,
  );
  await expectBody(
    'multi-path PATCH: refused write left head unchanged (atomic)',
    call('GET', o('head/seq'), gm),
    (c, t) => c == 200 && jsonDecode(t) == 1,
  );
  await expectCode(
    'root PATCH: status archived across paths is refused',
    call('PATCH', '/', gm, body: {'operations/$op/meta/status': 'archived'}),
    401,
  );
  await expectCode(
    'multi-path PATCH: gm cannot delete meta',
    call('PATCH', '/operations/$op', gm, body: {'meta': null}),
    401,
  );
  await expectCode(
    'multi-path PATCH: gm cannot delete meta/status with head',
    call(
      'PATCH',
      '/operations/$op',
      gm,
      body: {
        'meta/status': null,
        'head': {'seq': 3},
      },
    ),
    401,
  );
  await expectCode(
    'PATCH on meta: gm cannot set status archived',
    call('PATCH', o('meta'), gm, body: {'status': 'archived'}),
    401,
  );
  await expectCode(
    'root PUT of the operation node is refused (no write rule there)',
    call(
      'PUT',
      '/operations/$op',
      gm,
      body: {
        'meta': {'gm': 'gm1', 'status': 'paused'},
      },
    ),
    401,
  );
  await expectCode(
    'DELETE of the operation node is refused',
    call('DELETE', '/operations/$op', gm),
    401,
  );
  await expectCode(
    'gm cannot remove status (validate)',
    call('DELETE', o('meta/status'), gm),
    401,
  );
  await expectCode(
    'gm cannot replace meta without status (validate)',
    call('PUT', o('meta'), gm, body: {'gm': 'gm1', 'lastSeq': 1}),
    401,
  );
  await expectCode(
    'status must be a string (validate)',
    call('PUT', o('meta/status'), gm, body: 3),
    401,
  );
  await expectCode(
    'locked must be a boolean (validate)',
    call('PUT', o('meta/locked'), gm, body: 'yes'),
    401,
  );
  await expectCode(
    'gm can set locked false before the lock',
    call('PUT', o('meta/locked'), gm, body: false),
    200,
  );
  await expectCode(
    'gm cannot remove locked once set, even before the lock (validate)',
    call('DELETE', o('meta/locked'), gm),
    401,
  );
  await expectCode(
    'gm cannot replace meta dropping locked once set (validate)',
    call('PUT', o('meta'), gm, body: {'gm': 'gm1', 'status': 'paused'}),
    401,
  );
  await expectBody(
    'locked is still false after the removal attempts',
    call('GET', o('meta/locked'), admin),
    (c, t) => c == 200 && jsonDecode(t) == false,
  );
  await expectCode(
    'full account cannot create an operation without status (validate)',
    call('PUT', '/operations/op3/meta', p2, body: {'gm': 'p2'}),
    401,
  );

  // ---- ruling 1: meta is never deleted ----
  await expectCode(
    'gm cannot delete meta of an unlocked operation (ruling 1)',
    call('DELETE', o('meta'), gm),
    401,
  );
  await expectCode(
    'gm cannot delete meta/gm (ruling 1)',
    call('DELETE', o('meta/gm'), gm),
    401,
  );
  await expectCode(
    'gm cannot replace meta without a gm field (ruling 1)',
    call('PUT', o('meta'), gm, body: {'status': 'active'}),
    401,
  );
  await expectCode(
    'gm cannot delete the whole operation node',
    call('DELETE', '/operations/$op', gm),
    401,
  );
  await expectCode(
    'gm cannot delete meta in a multi-path update at the operation node',
    call('PATCH', '/operations/$op', gm, body: {'meta': null}),
    401,
  );
  await expectCode(
    'gm cannot delete meta in a multi-path update at the root',
    call('PATCH', '/', gm, body: {'operations/$op/meta': null}),
    401,
  );
  await expectCode(
    'another account still cannot recreate meta after the delete attempts',
    call('PUT', o('meta'), p2, body: {'gm': 'p2'}),
    401,
  );
  await expectBody(
    'meta still names the gm after the delete attempts',
    call('GET', o('meta/gm'), admin),
    (c, t) => c == 200 && jsonDecode(t) == 'gm1',
  );

  // ---- joins ----
  await expectCode(
    'player cannot add self to members',
    call('PUT', o('members/p1'), p1, body: {'aliasId': 'a1', 'joinedAt': 1}),
    401,
  );
  await expectCode(
    'gm adds anonymous player as member',
    call('PUT', o('members/p1'), gm, body: {'aliasId': 'a1', 'joinedAt': 1}),
    200,
  );
  await expectCode(
    'gm adds full-account player as member',
    call('PUT', o('members/p2'), gm, body: {'aliasId': 'a2', 'joinedAt': 1}),
    200,
  );
  await expectCode(
    'member entry without aliasId is rejected (validate)',
    call('PUT', o('members/p3'), gm, body: {'joinedAt': 1}),
    401,
  );
  await expectCode(
    'member entry with bad aliasId chars rejected (validate)',
    call('PUT', o('members/p3'), gm, body: {'aliasId': 'a/b c', 'joinedAt': 1}),
    401,
  );
  await expectCode(
    'player reads own member entry',
    call('GET', o('members/p1'), p1),
    200,
  );
  await expectCode(
    'player cannot read other member entry',
    call('GET', o('members/p2'), p1),
    401,
  );
  await expectCode(
    'player cannot list members',
    call('GET', o('members'), p1),
    401,
  );
  await expectCode('gm lists members', call('GET', o('members'), gm), 200);

  // ---- meta reads ----
  await expectCode('member reads meta', call('GET', o('meta'), p1), 200);
  await expectCode(
    'non-member cannot read meta',
    call('GET', o('meta'), out),
    401,
  );
  await expectCode(
    'member cannot write meta',
    call('PUT', o('meta/status'), p2, body: 'archived'),
    401,
  );

  // ---- events: gm writes, audiences ----
  for (final a in ['gm', 'public', 'alias:a1', 'alias:a2']) {
    for (var s = 1; s <= 3; s++) {
      await expectCode(
        'gm appends event seq $s to $a',
        call('PUT', o('events/$a/e$s'), gm, body: {'seq': s, 'body': 'x$s'}),
        200,
      );
    }
  }
  await expectCode(
    'member cannot write events',
    call('PUT', o('events/public/zz'), p2, body: {'seq': 9, 'body': 'x'}),
    401,
  );
  await expectCode(
    'gm cannot overwrite an event (append-only)',
    call('PUT', o('events/public/e1'), gm, body: {'seq': 1, 'body': 'changed'}),
    401,
  );
  await expectCode(
    'gm cannot delete an event (append-only)',
    call('DELETE', o('events/public/e1'), gm),
    401,
  );
  await expectCode(
    'malformed event rejected (no body)',
    call('PUT', o('events/public/bad1'), gm, body: {'seq': 4}),
    401,
  );
  await expectCode(
    'event with string seq rejected',
    call('PUT', o('events/public/bad2'), gm, body: {'seq': '4', 'body': 'x'}),
    401,
  );
  await expectCode(
    'bad audience key rejected',
    call('PUT', o('events/everyone/e1'), gm, body: {'seq': 1, 'body': 'x'}),
    401,
  );
  await expectCode('gm reads all audiences', call('GET', o('events'), gm), 200);
  await expectCode(
    'player cannot read events root',
    call('GET', o('events'), p1),
    401,
  );
  await expectCode(
    'player reads public',
    call('GET', o('events/public'), p1),
    200,
  );
  await expectCode(
    'player reads own alias branch',
    call('GET', o('events/alias:a1'), p1),
    200,
  );
  await expectCode(
    'player cannot read other alias branch',
    call('GET', o('events/alias:a2'), p1),
    401,
  );
  await expectCode(
    'player cannot read gm branch',
    call('GET', o('events/gm'), p1),
    401,
  );
  await expectCode(
    'non-member cannot read public',
    call('GET', o('events/public'), out),
    401,
  );
  await expectCode(
    'unauthenticated cannot read public',
    call('GET', o('events/public'), none),
    401,
  );
  await expectBody(
    'player resync: orderBy seq startAt 2 on public (indexed)',
    call(
      'GET',
      o('events/public'),
      p1,
      q: {'orderBy': '"seq"', 'startAt': '2'},
    ),
    (c, t) => c == 200 && (jsonDecode(t) as Map).length == 2,
  );
  await expectBody(
    'player tail: orderBy seq limitToLast 1 on own alias',
    call(
      'GET',
      o('events/alias:a1'),
      p1,
      q: {'orderBy': '"seq"', 'limitToLast': '1'},
    ),
    (c, t) => c == 200 && (jsonDecode(t) as Map).length == 1,
  );
  await expectBody(
    'player resync via orderBy \$key startAt (needs no index)',
    call(
      'GET',
      o('events/public'),
      p1,
      q: {'orderBy': '"\$key"', 'startAt': '"e2"'},
    ),
    (c, t) => c == 200 && (jsonDecode(t) as Map).length == 2,
  );
  await expectCode(
    'query on unindexed child (body) is refused by REST (needs indexOn)',
    call(
      'GET',
      o('events/public'),
      p1,
      q: {'orderBy': '"body"', 'limitToFirst': '1'},
    ),
    400,
  );
  await expectCode(
    'gm reads own gm branch via the events-level read',
    call('GET', o('events/gm'), gm),
    200,
  );
  await expectCode(
    'gm listener on audience branch with orderBy seq',
    call('GET', o('events/gm'), gm, q: {'orderBy': '"seq"', 'startAt': '3'}),
    200,
  );
  await expectCode(
    'textlog append public',
    call('PUT', o('textlog/public/t1'), gm, body: {'seq': 1, 'text': 'hello'}),
    200,
  );
  await expectCode(
    'player cannot read textlog gm',
    call('GET', o('textlog/gm'), p1),
    401,
  );
  await expectCode(
    'player reads textlog public',
    call('GET', o('textlog/public'), p1),
    200,
  );

  // ---- requests ----
  await expectCode(
    'member writes own request',
    call(
      'PUT',
      o('requests/p1/r1'),
      p1,
      body: {'id': 'r1', 'kind': 'roll', 'from': 'p1'},
    ),
    200,
  );
  await expectCode(
    'member cannot write under another uid',
    call(
      'PUT',
      o('requests/p2/r2'),
      p1,
      body: {'id': 'r2', 'kind': 'roll', 'from': 'p1'},
    ),
    401,
  );
  await expectCode(
    'request with forged from rejected',
    call(
      'PUT',
      o('requests/p1/r3'),
      p1,
      body: {'id': 'r3', 'kind': 'roll', 'from': 'p2'},
    ),
    401,
  );
  await expectCode(
    'request overwrite denied (append-only)',
    call(
      'PUT',
      o('requests/p1/r1'),
      p1,
      body: {'id': 'r1', 'kind': 'roll', 'from': 'p1'},
    ),
    401,
  );
  await expectCode(
    'non-member cannot write request',
    call(
      'PUT',
      o('requests/out1/r1'),
      out,
      body: {'id': 'r1', 'kind': 'roll', 'from': 'out1'},
    ),
    401,
  );
  await expectCode(
    'player cannot write at requests/<uid> level',
    call(
      'PUT',
      o('requests/p1'),
      p1,
      body: {
        'x': {'id': 'r', 'kind': 'k', 'from': 'p1'},
      },
    ),
    401,
  );
  await expectCode(
    'player cannot read own requests',
    call('GET', o('requests/p1'), p1),
    401,
  );
  await expectCode(
    'gm reads all requests',
    call('GET', o('requests'), gm),
    200,
  );
  await expectCode(
    'gm clears a processed request',
    call('DELETE', o('requests/p1/r1'), gm),
    200,
  );

  // ---- head ----
  await expectCode(
    'gm writes head',
    call('PUT', o('head'), gm, body: {'seq': 3, 'state': 'blob'}),
    200,
  );
  await expectCode('player cannot read head', call('GET', o('head'), p1), 401);
  await expectCode(
    'player cannot write head',
    call('PUT', o('head'), p2, body: {'seq': 99}),
    401,
  );

  // ---- phone (P17: GM and player messages in one box per player) ----
  await expectCode(
    'phoneDraft path is gone (P23): member cannot write it',
    call('PUT', o('phoneDraft/m1'), p2, body: {'from': 'p2', 'text': 'hi'}),
    401,
  );
  await expectCode(
    'phone/<uid>: member writes own box',
    call('PUT', o('phone/p2/m1'), p2, body: {'from': 'p2', 'text': 'hi'}),
    200,
  );
  await expectCode(
    'phone/<uid>: member cannot write into another box',
    call('PUT', o('phone/p1/m2'), p2, body: {'from': 'p2', 'text': 'hi'}),
    401,
  );
  await expectCode(
    'phone/<uid>: forged from rejected',
    call('PUT', o('phone/p2/m3'), p2, body: {'from': 'p1', 'text': 'hi'}),
    401,
  );
  await expectCode(
    'phone/<uid>: message without text rejected (validate)',
    call('PUT', o('phone/p2/v1'), p2, body: {'from': 'p2'}),
    401,
  );
  await expectCode(
    'phone/<uid>: gm message without from rejected (validate)',
    call('PUT', o('phone/p2/v2'), gm, body: {'text': 'hi'}),
    401,
  );
  await expectCode(
    'phone/<uid>: non-string text rejected (validate)',
    call('PUT', o('phone/p2/v3'), p2, body: {'from': 'p2', 'text': 42}),
    401,
  );
  await expectCode(
    'phone/<uid>: text of exactly 2,000 characters accepted',
    call('PUT', o('phone/p2/v4'), p2, body: {'from': 'p2', 'text': 'a' * 2000}),
    200,
  );
  await expectCode(
    'phone/<uid>: text over 2,000 characters rejected (validate)',
    call('PUT', o('phone/p2/v5'), p2, body: {'from': 'p2', 'text': 'a' * 2001}),
    401,
  );
  await expectCode(
    'phone/<uid>: gm text over 2,000 characters rejected (validate)',
    call(
      'PUT',
      o('phone/p2/v6'),
      gm,
      body: {'from': 'npc7', 'text': 'a' * 2001},
    ),
    401,
  );
  // `.length` counts UTF-16 code units, so an emoji counts as 2.
  await expectCode(
    'phone/<uid>: 1,000 emoji (2,000 UTF-16 units) accepted',
    call(
      'PUT',
      o('phone/p2/v7'),
      p2,
      body: {'from': 'p2', 'text': '\u{1F600}' * 1000},
    ),
    200,
  );
  await expectCode(
    'phone/<uid>: 1,001 emoji (2,002 UTF-16 units) rejected',
    call(
      'PUT',
      o('phone/p2/v8'),
      p2,
      body: {'from': 'p2', 'text': '\u{1F600}' * 1001},
    ),
    401,
  );
  await expectCode(
    'phone/<uid>: member cannot delete own message (create-only)',
    call('DELETE', o('phone/p2/m1'), p2),
    401,
  );
  await expectCode(
    'phone/<uid>: anonymous member cannot send a message (no messaging for tier 0)',
    call('PUT', o('phone/p1/a1'), p1, body: {'from': 'p1', 'text': 'hi'}),
    401,
  );
  await expectCode(
    'phone/<uid>: anonymous member reads own box',
    call('GET', o('phone/p1'), p1),
    200,
  );
  await expectCode(
    'phone/<uid>: gm delivers into a player box',
    call('PUT', o('phone/p1/m4'), gm, body: {'from': 'npc7', 'text': 'boo'}),
    200,
  );
  await expectCode(
    'phone/<uid>: gm cannot delete a message (create-only)',
    call('DELETE', o('phone/p1/m4'), gm),
    401,
  );
  await expectCode(
    'phone/<uid>: owner lists own box',
    call('GET', o('phone/p1'), p1),
    200,
  );
  await expectCode(
    'phone/<uid>: other player cannot list box',
    call('GET', o('phone/p1'), p2),
    401,
  );
  await expectCode(
    'phone: gm lists whole phone tree (read at phone level)',
    call('GET', o('phone'), gm),
    200,
  );
  await expectCode(
    'phone/<uid>: gm lists a box',
    call('GET', o('phone/p1'), gm),
    200,
  );

  // ---- ruling 2: signaling keyed by uid ----
  await expectCode(
    'gm adds a second full-account player as member',
    call('PUT', o('members/p4'), gm, body: {'aliasId': 'a4', 'joinedAt': 1}),
    200,
  );
  await expectCode(
    'member writes own signaling branch',
    call('PUT', o('signaling/p2/offer'), p2, body: 'sdp2'),
    200,
  );
  await expectCode(
    'full-account member cannot overwrite another uid\'s signaling (ruling 2)',
    call('PUT', o('signaling/p2/offer'), p4, body: 'x'),
    401,
  );
  await expectCode(
    'full-account member cannot write into another uid\'s signaling (ruling 2)',
    call('PUT', o('signaling/p2/answer'), p4, body: 'x'),
    401,
  );
  await expectCode(
    'member cannot write the signaling root',
    call(
      'PUT',
      o('signaling'),
      p1,
      body: {
        'p2': {'offer': 'x'},
      },
    ),
    401,
  );
  await expectCode(
    'anonymous member cannot write own signaling (no voice or video for tier 0)',
    call('PUT', o('signaling/p1/offer'), p1, body: 'sdp-anon'),
    401,
  );
  await expectCode(
    'gm writes any uid\'s signaling branch',
    call('PUT', o('signaling/p1/offer'), gm, body: 'sdp-gm'),
    200,
  );
  await expectCode(
    'non-member cannot write own-uid signaling',
    call('PUT', o('signaling/out1/offer'), out, body: 'x'),
    401,
  );
  await expectCode(
    'full-account member reads another uid\'s signaling (read scope as probed)',
    call('GET', o('signaling/p2'), p4),
    200,
  );
  await expectCode(
    'anonymous member cannot read any signaling (no voice or video for tier 0)',
    call('GET', o('signaling/p2'), p1),
    401,
  );
  await expectCode(
    'anonymous member cannot read own-uid signaling either',
    call('GET', o('signaling/p1'), p1),
    401,
  );
  await expectCode(
    'gm reads a uid\'s signaling',
    call('GET', o('signaling/p2'), gm),
    200,
  );
  await expectCode(
    'non-member cannot read signaling',
    call('GET', o('signaling/p2'), out),
    401,
  );

  // ---- presence, inbox ----
  await expectCode(
    'member writes own presence',
    call('PUT', '/presence/$op/p1', p1, body: true),
    200,
  );
  await expectCode(
    'member cannot write other presence',
    call('PUT', '/presence/$op/p2', p1, body: true),
    401,
  );
  await expectCode(
    'member reads presence list',
    call('GET', '/presence/$op', p2),
    200,
  );
  await expectCode(
    'non-member cannot read presence',
    call('GET', '/presence/$op', out),
    401,
  );
  await call('PUT', '/inbox/p1/n1', admin, body: {'t': 'hello'});
  await expectCode('owner reads inbox', call('GET', '/inbox/p1', p1), 200);
  await expectCode(
    'other user cannot read inbox',
    call('GET', '/inbox/p1', p2),
    401,
  );
  await expectCode(
    'owner cannot write inbox',
    call('PUT', '/inbox/p1/n2', p1, body: {'t': 'forged'}),
    401,
  );
  await expectCode(
    'owner deletes an inbox item',
    call('DELETE', '/inbox/p1/n1', p1),
    200,
  );
  await expectCode(
    'nothing outside the tree is writable',
    call('PUT', '/other/x', gm, body: 1),
    401,
  );

  // ---- lock ----
  await expectCode(
    'gm locks the operation',
    call('PUT', o('meta/locked'), gm, body: true),
    200,
  );
  await expectCode(
    'locked: gm cannot append event',
    call('PUT', o('events/public/e9'), gm, body: {'seq': 9, 'body': 'x'}),
    401,
  );
  await expectCode(
    'locked: gm cannot write head',
    call('PUT', o('head'), gm, body: {'seq': 9}),
    401,
  );
  await expectCode(
    'locked: gm cannot add member',
    call('PUT', o('members/p9'), gm, body: {'aliasId': 'a9', 'joinedAt': 1}),
    401,
  );
  await expectCode(
    'locked: gm cannot unlock',
    call('PUT', o('meta/locked'), gm, body: false),
    401,
  );
  await expectCode(
    'locked: gm cannot change status',
    call('PUT', o('meta/status'), gm, body: 'paused'),
    401,
  );
  await expectCode(
    'locked: gm cannot set status archived',
    call('PUT', o('meta/status'), gm, body: 'archived'),
    401,
  );
  await expectCode(
    'locked: gm cannot delete meta (ruling 1)',
    call('DELETE', o('meta'), gm),
    401,
  );
  await expectCode(
    'locked: gm cannot replace meta without a gm field (ruling 1)',
    call('PUT', o('meta'), gm, body: {'status': 'active'}),
    401,
  );
  await expectCode(
    'locked: gm cannot delete the whole operation node',
    call('DELETE', '/operations/$op', gm),
    401,
  );
  await expectCode(
    'locked: another account cannot take over meta',
    call('PUT', o('meta'), p2, body: {'gm': 'p2'}),
    401,
  );
  await expectCode(
    'locked: member cannot write request',
    call(
      'PUT',
      o('requests/p2/r9'),
      p2,
      body: {'id': 'r9', 'kind': 'k', 'from': 'p2'},
    ),
    401,
  );
  await expectCode(
    'locked: member cannot send phone message',
    call('PUT', o('phone/p2/m9'), p2, body: {'from': 'p2', 'text': 'x'}),
    401,
  );
  await expectCode(
    'locked: member cannot write own signaling (ruling 3)',
    call('PUT', o('signaling/p2/candidate'), p2, body: 'c1'),
    401,
  );
  await expectCode(
    'locked: gm cannot write signaling (ruling 3)',
    call('PUT', o('signaling/p2/answer'), gm, body: 'x'),
    401,
  );
  await expectCode(
    'locked: member can still write own presence',
    call('PUT', '/presence/$op/p1', p1, body: false),
    200,
  );
  await expectCode(
    'locked: members can still read public events',
    call('GET', o('events/public'), p2),
    200,
  );
  // ---- multi-path PATCH and root PUT, after the lock ----
  await expectCode(
    'locked: multi-path PATCH of status and an event is refused',
    call(
      'PATCH',
      '/operations/$op',
      gm,
      body: {
        'meta/status': 'paused',
        'events/public/e8': {'seq': 8, 'body': 'x'},
      },
    ),
    401,
  );
  await expectBody(
    'locked: refused PATCH wrote no event (atomic)',
    call('GET', o('events/public/e8'), gm),
    (c, t) => c == 200 && jsonDecode(t) == null,
  );
  await expectCode(
    'locked: PATCH cannot unlock',
    call('PATCH', '/operations/$op', gm, body: {'meta/locked': false}),
    401,
  );
  await expectCode(
    'locked: PATCH cannot remove locked',
    call('PATCH', '/operations/$op', gm, body: {'meta/locked': null}),
    401,
  );
  await expectCode(
    'locked: PATCH cannot delete meta',
    call('PATCH', '/operations/$op', gm, body: {'meta': null}),
    401,
  );
  await expectCode(
    'locked: root PUT of the operation node is refused',
    call(
      'PUT',
      '/operations/$op',
      gm,
      body: {
        'meta': {'gm': 'gm1', 'status': 'archived', 'locked': false},
      },
    ),
    401,
  );
  await expectCode(
    'locked: DELETE of the operation node is refused',
    call('DELETE', '/operations/$op', gm),
    401,
  );
  await expectCode(
    'locked: gm can still read head',
    call('GET', o('head'), gm),
    200,
  );

  // ---- review additions (run after lock) ----
  await expectCode(
    'non-member cannot read alias:null branch (null aliasId must not match)',
    call('GET', o('events/alias:null'), out),
    401,
  );
  await expectCode(
    'non-member cannot read textlog alias:null branch',
    call('GET', o('textlog/alias:null'), out),
    401,
  );
  await expectCode(
    'random user cannot read textlog alias branch',
    call('GET', o('textlog/alias:a1'), out),
    401,
  );
  await expectCode(
    'player cannot read textlog other alias',
    call('GET', o('textlog/alias:a2'), p1),
    401,
  );
  await expectCode(
    'player cannot read textlog root',
    call('GET', o('textlog'), p1),
    401,
  );
  await expectCode(
    'non-member cannot read textlog public',
    call('GET', o('textlog/public'), out),
    401,
  );
  await expectCode(
    'non-member cannot read textlog root',
    call('GET', o('textlog'), out),
    401,
  );
  await expectCode(
    'non-member cannot read textlog gm branch',
    call('GET', o('textlog/gm'), out),
    401,
  );
  await expectCode(
    'unauthenticated cannot read textlog public',
    call('GET', o('textlog/public'), none),
    401,
  );
  await expectCode('gm reads textlog root', call('GET', o('textlog'), gm), 200);
  await expectCode(
    'gm cannot overwrite textlog entry',
    call('PUT', o('textlog/public/t1'), gm, body: {'seq': 1, 'text': 'x'}),
    401,
  );
  await expectCode(
    'gm cannot delete textlog entry',
    call('DELETE', o('textlog/public/t1'), gm),
    401,
  );
  await expectCode(
    'member entry without joinedAt rejected',
    call('PUT', o('members/p3'), gm, body: {'aliasId': 'a3'}),
    401,
  );
  await expectCode(
    'player cannot read others requests',
    call('GET', o('requests/p2'), p1),
    401,
  );
  await expectCode(
    'anonymous player cannot write meta',
    call('PUT', o('meta/status'), p1, body: 'x'),
    401,
  );
  await expectCode(
    'anonymous player cannot write head',
    call('PUT', o('head'), p1, body: {'a': 1}),
    401,
  );
  await expectCode(
    'anonymous player cannot append events',
    call('PUT', o('events/public/q1'), p1, body: {'seq': 7, 'body': 'x'}),
    401,
  );
  await expectCode(
    'player cannot read head even with an orderBy \$key query',
    call('GET', o('head'), p1, q: {'orderBy': '"\$key"'}),
    401,
  );

  // ---- archive step: the function marks the operation archived. Only
  // admin REST can set this value; the rules refuse it from any client ----
  await expectCode(
    'archive: function marks the operation archived (admin)',
    call('PUT', o('meta/status'), admin, body: 'archived'),
    200,
  );

  // ---- post-archive clean-up (R 2026-10-21): admin REST deletes live
  // branches, meta and members stay as the locked stub ----
  for (final branch in [
    'events',
    'textlog',
    'requests',
    'head',
    'phone',
    'signaling',
  ]) {
    await expectCode(
      'clean-up: function deletes $branch',
      call('DELETE', o(branch), admin),
      200,
    );
  }
  await expectCode(
    'clean-up: function deletes presence',
    call('DELETE', '/presence/$op', admin),
    200,
  );
  await expectBody(
    'clean-up: only meta and members remain',
    call('GET', '/operations/$op', admin, q: {'shallow': 'true'}),
    (c, t) =>
        c == 200 &&
        (jsonDecode(t) as Map).keys.toSet().containsAll({'meta', 'members'}) &&
        (jsonDecode(t) as Map).length == 2,
  );
  await expectBody(
    'clean-up: meta stays locked',
    call('GET', o('meta/locked'), admin),
    (c, t) => c == 200 && jsonDecode(t) == true,
  );
  await expectCode(
    'clean-up: member still reads meta',
    call('GET', o('meta'), p1),
    200,
  );
  await expectCode(
    'clean-up: player still reads own member entry',
    call('GET', o('members/p1'), p1),
    200,
  );
  await expectCode(
    'clean-up: gm cannot delete the stub meta (ruling 1)',
    call('DELETE', o('meta'), gm),
    401,
  );
  await expectCode(
    'clean-up: gm cannot write events again',
    call('PUT', o('events/public/z1'), gm, body: {'seq': 1, 'body': 'x'}),
    401,
  );
  await expectCode(
    'clean-up: member cannot write signaling again',
    call('PUT', o('signaling/p2/offer'), p2, body: 'x'),
    401,
  );
  await expectCode(
    'archived: member cannot write own presence again',
    call('PUT', '/presence/$op/p2', p2, body: true),
    401,
  );
  await expectCode(
    'archived: anonymous member cannot write own presence again',
    call('PUT', '/presence/$op/p1', p1, body: true),
    401,
  );

  print(lines.join('\n'));
  print('\n$pass passed, $fail failed');
  client.close();
  exit(fail == 0 ? 0 : 1);
}
