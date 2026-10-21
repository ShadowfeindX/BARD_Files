# protocol_envelope

The wire envelope, message types, refusal reasons, version negotiation and JSON
codec of the B.A.R.D. protocol (spec: `docs/architecture/03-protocol.md`).

Dart SDK only (F4): no engine, no Flutter, no Firebase. `apps/functions` can
depend on it alone. Engine commands, events and state cross the wire as opaque
JSON maps; their codecs live in `protocol`.

## Use

```dart
const codec = JsonEnvelopeCodec();

final frame = codec.encode(Envelope.of(
  const Request(requestId: 'r1', command: {'type': 'RequestAction'}),
  engineVersion: const EngineVersion(1, 4, 0),
  operationId: 'op_01J8Z3',
  from: 'alias_7',
));

final envelope = codec.decode(frame);      // header only; never throws on an unknown `type`
final message = envelope.message;          // typed body; throws ProtocolFormatException if malformed
```

The host checks a `hello` with `negotiateHello(...)`, which returns the
`Refused` to send or null.

## Files

| File | Holds |
|---|---|
| `src/envelope.dart` | `Envelope` (`p`, `e`, `op`, `seq`, `from`, `type`, `body`) |
| `src/messages.dart` | `MessageType` and one class per message |
| `src/refusal_reason.dart` | `RefusalReason` |
| `src/negotiation.dart` | `negotiateHello` (03 §Version negotiation, rules 1 to 3) |
| `src/codec.dart` | `EnvelopeCodec` interface and `JsonEnvelopeCodec` |
| `src/engine_version.dart` | `EngineVersion` (`major.minor.patch`) |
| `test/fixtures/v1/` | One frame per message type; old frames must keep decoding |

## Decisions worth knowing

- The header decodes without the body, and `type` is a string, so a host can
  read a frame from a different protocol major and answer `refused`.
- Within a protocol major, a refusal reason this version does not know decodes
  as `RefusalReason.unknown` and keeps its raw string.
- The envelope `seq` is set on `events` frames only (the first event's `seq`).

Fields and layouts that the spec does not pin down are marked **Proposed** in
the doc comments and listed in `docs/architecture/03-protocol.md`.
