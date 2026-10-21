import 'dart:convert';
import 'dart:io';

import 'package:engine/engine.dart';
import 'package:protocol/protocol.dart';
import 'package:protocol_envelope/protocol_envelope.dart';
import 'package:test/test.dart';

import 'support/samples.dart';

Object? readFixture(String path) =>
    jsonDecode(File('test/fixtures/v1/$path').readAsStringSync());

String fixtureFile(String path) =>
    File('test/fixtures/v1/$path').readAsStringSync();

/// The text a fixture file holds: two-space indented JSON and a newline.
String fixtureText(Object? json) =>
    '${const JsonEncoder.withIndent('  ').convert(json)}\n';

/// JSON as a wire frame would carry it: encoded to text and parsed back.
Object? onTheWire(Object? json) => jsonDecode(jsonEncode(json));

void main() {
  group('commands', () {
    sampleCommands.forEach((type, command) {
      test('$type round-trips through JSON text', () {
        final json = onTheWire(encodeCommand(command));
        expect((json as Map)['type'], type);
        expect(decodeCommand(json), command);
      });

      test('$type matches its v1 fixture and still decodes it', () {
        expect(
          fixtureText(encodeCommand(command)),
          fixtureFile('commands/$type.json'),
        );
        expect(decodeCommand(readFixture('commands/$type.json')), command);
      });
    });

    test('there is one fixture per sample and no strays', () {
      final files = Directory('test/fixtures/v1/commands')
          .listSync()
          .map((f) => f.uri.pathSegments.last.replaceAll('.json', ''));
      expect(files, unorderedEquals(sampleCommands.keys));
    });
  });

  group('events', () {
    sampleEvents.forEach((type, event) {
      test('$type round-trips through JSON text', () {
        final json = onTheWire(encodeEvent(event));
        expect((json as Map)['type'], type);
        expect(decodeEvent(json), event);
      });

      test('$type matches its v1 fixture and still decodes it', () {
        expect(
          fixtureText(encodeEvent(event)),
          fixtureFile('events/$type.json'),
        );
        expect(decodeEvent(readFixture('events/$type.json')), event);
      });
    });

    test('there is one fixture per sample and no strays', () {
      final files = Directory('test/fixtures/v1/events')
          .listSync()
          .map((f) => f.uri.pathSegments.last.replaceAll('.json', ''));
      expect(files, unorderedEquals(sampleEvents.keys));
    });

    test('the breakdown total survives the trip', () {
      final resolved = decodeEvent(
        onTheWire(encodeEvent(sampleEvents['checkResolved']!)),
      ) as CheckResolved;
      expect(resolved.total, 6 + 3 + 2 + 2 - 2);
    });
  });

  group('optional and alternative shapes', () {
    final extras = <Command>[
      RequireCheck(
        entity: vale,
        attribute: 'WIL',
        difficulty: const FixedDifficulty(12),
      ),
      CreateAgent(name: 'Nobody', attributes: {'WIL': 1}),
      const StartOperation(
        operationId: 'op_2',
        settings: OperationSettings(
          autoResolveChecks: true,
          autoConfirmConsequences: true,
          autoApplyEngineUpdates: false,
          autoApplyPackUpdates: true,
        ),
      ),
      const ApplyDamage(entity: vale, amount: 0),
    ];
    for (final command in extras) {
      test('${command.runtimeType} with nulls and other settings', () {
        expect(decodeCommand(onTheWire(encodeCommand(command))), command);
      });
    }

    test('an event with every optional field empty', () {
      final event = CheckResolved(
        check: const CheckId('c2'),
        spec: CheckSpec(entity: vale, attribute: 'WIL', dc: 3),
        breakdown: CheckBreakdown(
          primary: ConstTerm(1),
          attribute: 'WIL',
          attributeScore: 2,
        ),
        outcome: CheckOutcome.failure,
        draws: DrawRange(0, 0),
        actor: const GmActor(),
        visibility: const GmOnly(),
      );
      expect(decodeEvent(onTheWire(encodeEvent(event))), event);
    });

    test('equal values encode to the same text whatever the key order', () {
      final a = CreateAgent(name: 'A', attributes: {'STR': 1, 'WIL': 2});
      final b = CreateAgent(name: 'A', attributes: {'WIL': 2, 'STR': 1});
      expect(a, b);
      expect(jsonEncode(encodeCommand(a)), jsonEncode(encodeCommand(b)));
    });
  });

  group('terms', () {
    test('every term kind round-trips', () {
      final resolved = CheckResolved(
        check: const CheckId('c9'),
        spec: CheckSpec(entity: vale, attribute: 'WIL', dc: 7),
        breakdown: CheckBreakdown(
          primary: SumTerm([
            ConstTerm(2),
            AttrTerm('WIL', 3),
            VarTerm('helperBonus', 1),
            KeepHighestTerm(
              options: [
                DiceTerm(
                  sides: 6,
                  explode: false,
                  rolls: [
                    DieRoll([4]),
                  ],
                ),
                ConstTerm(2.5),
              ],
              kept: [0],
            ),
            OpTerm(OpKind.div, [ConstTerm(5), ConstTerm(2)], 2.5),
          ]),
          attribute: 'WIL',
          attributeScore: 3,
        ),
        outcome: CheckOutcome.partialSuccess,
        draws: DrawRange(4, 5),
        source: RollSourceKind.entered,
        enteredBy: const AliasActor(valeAlias),
        actor: const GmActor(),
        visibility: const Public(),
      );
      expect(decodeEvent(onTheWire(encodeEvent(resolved))), resolved);
    });

    test('a whole-number double reads back as the same number', () {
      final json = onTheWire(
        encodeEvent(sampleEvents['checkResolved']!),
      ) as Map<String, Object?>;
      final primary = (json['breakdown']! as Map)['primary']! as Map;
      primary['type'] = 'const';
      primary['value'] = 9.0;
      final back = decodeEvent(json) as CheckResolved;
      expect(back.breakdown.primary, ConstTerm(9));
    });
  });

  group('full events', () {
    test('BroadcastDelivered keeps its whole recipient list', () {
      final json = encodeEvent(sampleEvents['broadcastDelivered']!);
      expect(
        jsonEncode(json),
        allOf(contains('al_vale'), contains('al_quinn')),
      );
    });

    test(
      'the GM-only broadcast record keeps the condition and every result',
      () {
        final json = jsonEncode(
          encodeEvent(sampleEvents['broadcastEvaluated']!),
        );
        expect(json, allOf(contains('compare'), contains('al_quinn')));
      },
    );
  });

  group('malformed and newer input', () {
    Map<String, Object?> sample() =>
        onTheWire(encodeEvent(sampleEvents['damageApplied']!))!
            as Map<String, Object?>;

    test('an unknown type is reported with its name', () {
      final json = sample()..['type'] = 'timeTravelled';
      expect(
        () => decodeEvent(json),
        throwsA(
          isA<UnknownTypeException>().having(
            (e) => e.type,
            'type',
            'timeTravelled',
          ),
        ),
      );
      expect(
        () => decodeCommand({...sample(), 'type': 'teleport'}),
        throwsA(isA<UnknownTypeException>()),
      );
    });

    test('a newer shape version is refused', () {
      final json = sample()..['v'] = shapeVersion + 1;
      expect(() => decodeEvent(json), throwsA(isA<ProtocolFormatException>()));
    });

    test('a missing or zero shape version is refused', () {
      expect(
        () => decodeEvent(sample()..remove('v')),
        throwsA(isA<ProtocolFormatException>()),
      );
      expect(
        () => decodeEvent(sample()..['v'] = 0),
        throwsA(isA<ProtocolFormatException>()),
      );
    });

    test('unknown extra fields are ignored (additive changes)', () {
      final json = sample()..['addedInAMinor'] = {'x': 1};
      expect(decodeEvent(json), sampleEvents['damageApplied']);
    });

    test('an optional field may be absent', () {
      final json = sample()
        ..remove('overriddenFrom')
        ..remove('check');
      final back = decodeEvent(json) as DamageApplied;
      expect(back.overriddenFrom, isNull);
      expect(back.check, isNull);
    });

    test('settings added later fall back to their defaults', () {
      final json =
          onTheWire(encodeCommand(sampleCommands['startOperation']!))!
              as Map<String, Object?>;
      (json['settings']! as Map).remove('autoApplyEngineUpdates');
      final back = decodeCommand(json) as StartOperation;
      expect(back.settings.autoApplyEngineUpdates, isTrue);
    });

    test('wrong field types name the field', () {
      final json = sample()..['amount'] = 'lots';
      expect(
        () => decodeEvent(json),
        throwsA(
          isA<ProtocolFormatException>().having(
            (e) => e.message,
            'message',
            contains('amount'),
          ),
        ),
      );
    });

    test('values the engine refuses become format errors', () {
      final json =
          onTheWire(encodeEvent(sampleEvents['checkResolved']!))!
              as Map<String, Object?>;
      json['draws'] = {'start': 5, 'end': 2};
      expect(() => decodeEvent(json), throwsA(isA<ProtocolFormatException>()));
      final aliases = sample()
        ..['visibility'] = {'kind': 'aliases', 'aliases': <String>[]};
      expect(
        () => decodeEvent(aliases),
        throwsA(isA<ProtocolFormatException>()),
      );
    });

    test('a broadcast must be delivered to aliases only', () {
      final json =
          onTheWire(encodeEvent(sampleEvents['broadcastDelivered']!))!
              as Map<String, Object?>;
      json['visibility'] = {'kind': 'public'};
      expect(() => decodeEvent(json), throwsA(isA<ProtocolFormatException>()));
    });

    Object? nested(int depth) {
      Object? inner = {'type': 'const', 'value': 1};
      for (var i = 0; i < depth; i++) {
        inner = {
          'type': 'sum',
          'terms': [inner],
        };
      }
      return inner;
    }

    test('deep nesting is refused instead of overflowing the stack', () {
      for (final depth in [40, 200, 20000]) {
        final json =
            onTheWire(encodeEvent(sampleEvents['checkResolved']!))!
                as Map<String, Object?>;
        (json['breakdown']! as Map)['primary'] = nested(depth);
        expect(
          () => decodeEvent(json),
          throwsA(isA<ProtocolFormatException>()),
          reason: 'depth $depth',
        );
      }
      final command =
          onTheWire(encodeCommand(sampleCommands['broadcastToQualifying']!))!
              as Map<String, Object?>;
      command['condition'] = nested(20000);
      expect(
        () => decodeCommand(command),
        throwsA(isA<ProtocolFormatException>()),
      );
    });

    test('a modest nesting depth still decodes', () {
      final json =
          onTheWire(encodeEvent(sampleEvents['checkResolved']!))!
              as Map<String, Object?>;
      (json['breakdown']! as Map)['primary'] = nested(10);
      expect(decodeEvent(json), isA<CheckResolved>());
    });

    test('a later minor type is unknown even with a new actor kind', () {
      final json =
          onTheWire(encodeEvent(sampleEvents['damageApplied']!))!
              as Map<String, Object?>;
      json['type'] = 'weatherChanged';
      json['actor'] = {'kind': 'system'};
      json.remove('visibility');
      expect(() => decodeEvent(json), throwsA(isA<UnknownTypeException>()));
      final command =
          onTheWire(encodeCommand(sampleCommands['applyDamage']!))!
              as Map<String, Object?>;
      command['type'] = 'rewind';
      command['actor'] = {'kind': 'system'};
      expect(
        () => decodeCommand(command),
        throwsA(isA<UnknownTypeException>()),
      );
    });

    test('terms the engine would refuse are refused', () {
      Map<String, Object?> withPrimary(Object? term) {
        final json =
            onTheWire(encodeEvent(sampleEvents['checkResolved']!))!
                as Map<String, Object?>;
        (json['breakdown']! as Map)['primary'] = term;
        return json;
      }

      final bad = <Object?>[
        {'type': 'dice', 'sides': 0, 'explode': null, 'rolls': <Object?>[]},
        {
          'type': 'dice',
          'sides': 6,
          'explode': null,
          'rolls': [
            [7],
          ],
        },
        {
          'type': 'dice',
          'sides': 6,
          'explode': null,
          'rolls': [
            [0],
          ],
        },
        {'type': 'sum', 'terms': <Object?>[]},
        {'type': 'op', 'op': 'sub', 'args': <Object?>[], 'value': 0},
      ];
      for (final term in bad) {
        expect(
          () => decodeEvent(withPrimary(term)),
          throwsA(isA<ProtocolFormatException>()),
          reason: '$term',
        );
      }
    });

    test('a broadcast record that claims to be public is refused', () {
      final json =
          onTheWire(encodeEvent(sampleEvents['broadcastEvaluated']!))!
              as Map<String, Object?>;
      json['visibility'] = {'kind': 'public'};
      expect(() => decodeEvent(json), throwsA(isA<ProtocolFormatException>()));
    });

    test('non-object input is a format error, not a crash', () {
      for (final bad in <Object?>[null, 3, 'x', <Object?>[]]) {
        expect(() => decodeEvent(bad), throwsA(isA<ProtocolFormatException>()));
        expect(
          () => decodeCommand(bad),
          throwsA(isA<ProtocolFormatException>()),
        );
      }
    });

    test('a condition with dice is refused', () {
      final json =
          onTheWire(encodeCommand(sampleCommands['broadcastToQualifying']!))!
              as Map<String, Object?>;
      (json['condition']! as Map)['left'] = {
        'type': 'dice',
        'count': 1,
        'sides': 6,
        'explode': false,
      };
      expect(
        () => decodeCommand(json),
        throwsA(isA<ProtocolFormatException>()),
      );
    });
  });

  group('inside an envelope', () {
    test('a command travels in a request body and an event in events', () {
      const codec = JsonEnvelopeCodec();
      final command = encodeCommand(sampleCommands['applyDamage']!);
      final request = Request(requestId: 'rq1', command: command);
      final frame = codec.encode(
        Envelope.of(
          request,
          engineVersion: const EngineVersion(1, 0, 0),
          operationId: 'op_1',
          from: 'al_vale',
        ),
      );
      final back = (codec.decode(frame).message as Request).command;
      expect(decodeCommand(back), sampleCommands['applyDamage']);
    });
  });
}
