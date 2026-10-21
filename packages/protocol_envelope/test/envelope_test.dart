import 'dart:convert';
import 'dart:io';

import 'package:protocol_envelope/protocol_envelope.dart';
import 'package:test/test.dart';

const codec = JsonEnvelopeCodec();
const v140 = EngineVersion(1, 4, 0);

Envelope wrap(Message m, {int? seq}) => Envelope.of(
  m,
  engineVersion: v140,
  operationId: 'op_1',
  from: gmSender,
  seq: seq,
);

/// Encodes, decodes, and returns the typed message.
Message roundTrip(Message m, {int? seq}) =>
    codec.decode(codec.encode(wrap(m, seq: seq))).message;

void main() {
  group('EngineVersion', () {
    test('parses and compares', () {
      expect(EngineVersion.parse('1.4.0'), v140);
      expect(
        EngineVersion.parse('1.10.0') < EngineVersion.parse('1.9.9'),
        isFalse,
      );
      expect(
        EngineVersion.parse('1.4.0') < EngineVersion.parse('1.4.1'),
        isTrue,
      );
      expect(v140.toString(), '1.4.0');
    });

    test('pre-releases parse and sort before their release (SemVer)', () {
      final dev1 = EngineVersion.parse('1.0.0-dev.1');
      expect(dev1.toString(), '1.0.0-dev.1');
      expect(dev1.isPreRelease, isTrue);
      final ordered = [
        '1.0.0-alpha',
        '1.0.0-alpha.1',
        '1.0.0-alpha.beta',
        '1.0.0-beta',
        '1.0.0-beta.2',
        '1.0.0-beta.11',
        '1.0.0-dev.1',
        '1.0.0-rc.1',
        '1.0.0',
        '1.0.1-dev.1',
      ].map(EngineVersion.parse).toList();
      for (var i = 0; i + 1 < ordered.length; i++) {
        expect(ordered[i] < ordered[i + 1], isTrue, reason: '${ordered[i]}');
        expect(ordered[i + 1] < ordered[i], isFalse, reason: '${ordered[i]}');
      }
      expect(dev1, EngineVersion.parse('1.0.0-dev.1'));
      expect(dev1 == EngineVersion.parse('1.0.0'), isFalse);
    });

    test('rejects anything but major.minor.patch[-pre.release]', () {
      for (final bad in [
        '1.4',
        '1.4.0+build',
        '1.4.0-',
        '1.4.0-01',
        '1.4.0-a..b',
        'v1.4.0',
        '',
        '1.4.x',
      ]) {
        expect(
          () => EngineVersion.parse(bad),
          throwsA(isA<ProtocolFormatException>()),
          reason: bad,
        );
      }
    });
  });

  group('Envelope', () {
    test('encodes the documented field names in order', () {
      final json = jsonDecode(
        codec.encode(wrap(const Ping(), seq: null)),
      ) as Map<String, Object?>;
      expect(json.keys, ['p', 'e', 'op', 'from', 'type', 'body']);
      expect(json['p'], 1);
      expect(json['e'], '1.4.0');
    });

    test('seq belongs to events only', () {
      expect(() => wrap(const Ping(), seq: 3), throwsArgumentError);
      expect(() => wrap(Events([{}])), throwsArgumentError);
      expect(() => wrap(Events([{}]), seq: 0), throwsArgumentError);
      final frame = codec.encode(wrap(Events([{}]), seq: 7));
      expect(codec.decode(frame).seq, 7);
    });

    test('decodes the header of a frame from another protocol major', () {
      final frame = jsonEncode({
        'p': 2,
        'e': '2.0.0',
        'op': 'op_1',
        'from': 'alias_1',
        'type': 'someFutureType',
        'body': {'anything': 1},
      });
      final envelope = codec.decode(frame);
      expect(envelope.protocol, 2);
      expect(envelope.messageType, isNull);
      expect(() => envelope.message, throwsA(isA<ProtocolFormatException>()));
    });

    test('malformed frames throw ProtocolFormatException', () {
      final good =
          jsonDecode(codec.encode(wrap(const Ping()))) as Map<String, Object?>;
      Map<String, Object?> without(String key) => {...good}..remove(key);
      expect(() => codec.decode('{'), throwsA(isA<ProtocolFormatException>()));
      expect(() => codec.decode('[]'), throwsA(isA<ProtocolFormatException>()));
      expect(() => codec.decode(42), throwsA(isA<ProtocolFormatException>()));
      for (final key in ['p', 'e', 'op', 'from', 'type']) {
        expect(
          () => codec.decode(jsonEncode(without(key))),
          throwsA(isA<ProtocolFormatException>()),
          reason: 'missing $key',
        );
      }
      expect(
        () => codec.decode(jsonEncode({...good, 'p': '1'})),
        throwsA(isA<ProtocolFormatException>()),
      );
      expect(
        () => codec.decode(jsonEncode({...good, 'p': 0})),
        throwsA(isA<ProtocolFormatException>()),
      );
      expect(
        () => codec.decode(jsonEncode({...good, 'e': '1.4'})),
        throwsA(isA<ProtocolFormatException>()),
      );
      expect(
        () => codec.decode(jsonEncode({...good, 'type': 'events'})).message,
        throwsA(isA<ProtocolFormatException>()),
        reason: 'events without seq',
      );
    });

    test('seq on a non-events frame is refused when decoding', () {
      final frame = jsonEncode({
        'p': 1,
        'e': '1.4.0',
        'op': 'o',
        'seq': 5,
        'from': 'gm',
        'type': 'ping',
        'body': <String, Object?>{},
      });
      expect(
        () => codec.decode(frame),
        throwsA(isA<ProtocolFormatException>()),
      );
    });

    test('a future-major header decodes even with an odd body', () {
      final frame = jsonEncode({
        'p': 2,
        'e': '2.0.0',
        'op': 'o',
        'from': 'a',
        'type': 'events',
      });
      final envelope = codec.decode(frame);
      expect(envelope.protocol, 2);
      expect(envelope.body, isEmpty);
      expect(() => envelope.message, throwsA(isA<ProtocolFormatException>()));
    });

    test('non-string map keys and huge versions are format errors', () {
      expect(
        () => Envelope.fromJson(<int, int>{1: 1}),
        throwsA(isA<ProtocolFormatException>()),
      );
      for (final bad in ['99999999999999999999.0.0', '01.4.0']) {
        expect(
          () => EngineVersion.parse(bad),
          throwsA(isA<ProtocolFormatException>()),
        );
      }
    });

    test('malformed bodies throw ProtocolFormatException', () {
      Envelope envelopeOf(String type, Map<String, Object?> body, {int? seq}) =>
          Envelope(
            protocol: 1,
            engineVersion: v140,
            operationId: 'op_1',
            from: 'gm',
            type: type,
            body: body,
            seq: seq,
          );
      final cases = [
        envelopeOf('hello', {}),
        envelopeOf('hello', {'agentId': 'a', 'kind': 'robot'}),
        envelopeOf('request', {'requestId': 'r', 'command': 'nope'}),
        envelopeOf('resync', {'lastSeq': '3'}),
        envelopeOf('resync', {'lastSeq': -1}),
        envelopeOf('hello', {'agentId': 'a', 'lastSeq': -5}),
        envelopeOf('welcome', {
          'settings': {},
          'snapshot': {'seq': 1},
        }),
        envelopeOf('welcome', {
          'settings': {},
          'pack': {'id': 'x'},
        }),
        envelopeOf('textlog', {
          'archive': 'a',
          'engineMajor': 0,
          'lines': [
            {'seq': 0, 'text': 't'},
          ],
        }),
        envelopeOf('refused', {
          'reason': 'updateRequired',
          'requiredEngine': '99999999999999999999.0.0',
        }),
        envelopeOf('presence', {'status': 'dancing'}),
        envelopeOf('refused', {
          'reason': 'updateRequired',
          'requiredEngine': '1.x',
        }),
        envelopeOf('events', {'events': []}, seq: 1),
        envelopeOf('events', {
          'events': [1],
        }, seq: 1),
      ];
      for (final envelope in cases) {
        expect(
          () => envelope.message,
          throwsA(isA<ProtocolFormatException>()),
          reason: jsonEncode(envelope.toJson()),
        );
      }
    });
  });

  group('Message round trips', () {
    test('hello', () {
      final m = roundTrip(
        const Hello(
          agentId: 'agent_3',
          aliasId: 'alias_7',
          kind: AgentKind.anonymous,
          authProof: 'p',
          lastSeq: 9,
        ),
      ) as Hello;
      expect(m.agentId, 'agent_3');
      expect(m.aliasId, 'alias_7');
      expect(m.kind, AgentKind.anonymous);
      expect(m.authProof, 'p');
      expect(m.lastSeq, 9);
    });

    test('hello defaults', () {
      final m = roundTrip(const Hello(agentId: 'a')) as Hello;
      expect(m.aliasId, isNull);
      expect(m.kind, AgentKind.full);
      expect(m.lastSeq, 0);
    });

    test('welcome', () {
      final m = roundTrip(
        const Welcome(
          settings: {'autoConfirm': true},
          pack: PackRef(id: 'core', version: '0.1.0', contentHash: 'h'),
          snapshot: Snapshot(seq: 5, state: {'a': 1}),
          events: [
            {'seq': 6},
          ],
        ),
      ) as Welcome;
      expect(m.settings, {'autoConfirm': true});
      expect(m.pack!.contentHash, 'h');
      expect(m.snapshot!.seq, 5);
      expect(m.snapshot!.state, {'a': 1});
      expect(m.events, [
        {'seq': 6},
      ]);
    });

    test('welcome without snapshot or events', () {
      final m = roundTrip(const Welcome(settings: {})) as Welcome;
      expect(m.snapshot, isNull);
      expect(m.pack, isNull);
      expect(m.events, isEmpty);
    });

    test('refused', () {
      final m = roundTrip(
        const Refused(
          reason: RefusalReason.updateRequired,
          message: 'update',
          hostProtocolMajor: 1,
          operationEngineMajor: 1,
          requiredEngineVersion: EngineVersion(1, 5, 0),
        ),
      ) as Refused;
      expect(m.reason, RefusalReason.updateRequired);
      expect(m.message, 'update');
      expect(m.hostProtocolMajor, 1);
      expect(m.operationEngineMajor, 1);
      expect(m.requiredEngineVersion, const EngineVersion(1, 5, 0));
    });

    test('every refusal reason survives the wire', () {
      for (final reason in RefusalReason.values) {
        if (reason == RefusalReason.unknown) continue;
        final m = roundTrip(Refused(reason: reason)) as Refused;
        expect(m.reason, reason);
      }
    });

    test('a refusal reason from a newer minor decodes as unknown', () {
      final envelope = Envelope(
        protocol: 1,
        engineVersion: v140,
        operationId: 'op_1',
        from: 'gm',
        type: 'refused',
        body: {'reason': 'quotaExceeded'},
      );
      final m = codec.decode(codec.encode(envelope)).message as Refused;
      expect(m.reason, RefusalReason.unknown);
      expect(m.unrecognizedCode, 'quotaExceeded');
      expect(m.toBody()['reason'], 'quotaExceeded');
    });

    test('request and rejected', () {
      final req = roundTrip(
        const Request(
          requestId: 'r1',
          command: {'type': 'RequestAction', 'n': 2},
        ),
      ) as Request;
      expect(req.requestId, 'r1');
      expect(req.command, {'type': 'RequestAction', 'n': 2});

      final rej = roundTrip(
        const Rejected(requestId: 'r1', code: 'nope', message: 'm'),
      ) as Rejected;
      expect((rej.requestId, rej.code, rej.message), ('r1', 'nope', 'm'));
    });

    test('events keep order and the first seq', () {
      final frame = codec.encode(
        wrap(
          Events([
            {'seq': 10},
            {'seq': 11},
            {'seq': 12},
          ]),
          seq: 10,
        ),
      );
      final envelope = codec.decode(frame);
      final m = envelope.message as Events;
      expect(envelope.seq, 10);
      expect(m.events.map((e) => e['seq']), [10, 11, 12]);
      expect(m.lastSeq(envelope.seq!), 12);
    });

    test('resync, textlog, presence, ping, pong', () {
      expect((roundTrip(const Resync(40)) as Resync).lastSeq, 40);

      final log = roundTrip(
        const TextLog(
          archiveOperationId: 'op_0',
          engineMajor: 0,
          lines: [TextLine(seq: 1, text: 'Hall rolls.')],
        ),
      ) as TextLog;
      expect(log.archiveOperationId, 'op_0');
      expect(log.engineMajor, 0);
      expect(log.lines.single.text, 'Hall rolls.');

      for (final status in PresenceStatus.values) {
        expect((roundTrip(Presence(status)) as Presence).status, status);
      }
      expect((roundTrip(const Ping(nonce: 'n')) as Ping).nonce, 'n');
      expect((roundTrip(const Pong(nonce: 'n')) as Pong).nonce, 'n');
      expect((roundTrip(const Ping()) as Ping).nonce, isNull);
    });

    test('UTF-16 and unicode text survives', () {
      const text = 'Sanity −3 \u{1F480} “quoted”';
      final m = roundTrip(
        const TextLog(
          archiveOperationId: 'o',
          engineMajor: 0,
          lines: [TextLine(seq: 1, text: text)],
        ),
      ) as TextLog;
      expect(m.lines.single.text, text);
    });

    test('there is a message class for every type', () {
      expect(MessageType.values, hasLength(11));
      const expected = {
        'hello': Hello,
        'welcome': Welcome,
        'refused': Refused,
        'request': Request,
        'rejected': Rejected,
        'resync': Resync,
        'textlog': TextLog,
        'presence': Presence,
        'ping': Ping,
        'pong': Pong,
      };
      for (final file in Directory('test/fixtures/v1').listSync()) {
        final name = file.uri.pathSegments.last.replaceAll('.json', '');
        if (name == 'events') continue;
        final m = codec.decode((file as File).readAsStringSync()).message;
        expect(m.runtimeType, expected[name], reason: name);
      }
      expect(MessageType.fromWire('nope'), isNull);
    });
  });

  group('Version negotiation', () {
    Refused? hello({
      int clientP = 1,
      EngineVersion client = v140,
      int hostP = 1,
      int opMajor = 1,
      EngineVersion? required,
    }) => negotiateHello(
      clientProtocol: clientP,
      clientEngine: client,
      hostProtocol: hostP,
      operationEngineMajor: opMajor,
      requiredEngine: required,
    );

    test('accepts a matching client', () {
      expect(hello(), isNull);
      expect(hello(required: v140), isNull);
      expect(hello(required: const EngineVersion(1, 3, 9)), isNull);
      expect(
        hello(client: const EngineVersion(1, 9, 0), required: v140),
        isNull,
      );
    });

    test('rule 1: protocol major', () {
      final r = hello(clientP: 2)!;
      expect(r.reason, RefusalReason.protocolMismatch);
      expect(r.hostProtocolMajor, 1);
    });

    test('rule 2: engine major, older or newer', () {
      for (final client in const [
        EngineVersion(0, 9, 0),
        EngineVersion(2, 0, 0),
      ]) {
        final r = hello(client: client)!;
        expect(r.reason, RefusalReason.engineMajorMismatch);
        expect(r.operationEngineMajor, 1);
      }
    });

    test('rule 3: update required, with the version needed', () {
      final r = hello(required: const EngineVersion(1, 4, 1))!;
      expect(r.reason, RefusalReason.updateRequired);
      expect(r.requiredEngineVersion, const EngineVersion(1, 4, 1));
      expect(
        hello(required: const EngineVersion(1, 5, 0))!.reason,
        RefusalReason.updateRequired,
      );
    });

    test('rules run in order: protocol, then major, then minor', () {
      expect(
        hello(clientP: 2, client: const EngineVersion(0, 1, 0))!.reason,
        RefusalReason.protocolMismatch,
      );
      expect(
        hello(
          client: const EngineVersion(2, 0, 0),
          required: const EngineVersion(1, 9, 0),
        )!.reason,
        RefusalReason.engineMajorMismatch,
      );
    });
  });

  group('Fixtures (old frames keep decoding within a major)', () {
    final dir = Directory('test/fixtures/v1');
    final files = dir.listSync().whereType<File>().toList()
      ..sort((a, b) => a.path.compareTo(b.path));

    test('there is one fixture per message type', () {
      final names = files.map((f) => f.uri.pathSegments.last).toSet();
      expect(names, {
        for (final type in MessageType.values) '${type.wire}.json',
      });
    });

    for (final file in files) {
      final name = file.uri.pathSegments.last;
      test('$name decodes and re-encodes unchanged', () {
        final text = file.readAsStringSync();
        final envelope = codec.decode(text);
        expect(envelope.messageType!.wire, name.replaceAll('.json', ''));
        expect(envelope.protocol, 1);
        // Round trip through the typed message as well as the raw body.
        final rebuilt = Envelope(
          protocol: envelope.protocol,
          engineVersion: envelope.engineVersion,
          operationId: envelope.operationId,
          seq: envelope.seq,
          from: envelope.from,
          type: envelope.type,
          body: envelope.message.toBody(),
        );
        expect(jsonDecode(codec.encode(rebuilt)), jsonDecode(text));
      });
    }
  });
}
