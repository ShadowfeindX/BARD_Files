# protocol

Hand-written JSON codecs between the engine's commands and events and the opaque bodies carried by `protocol_envelope` messages (`request.command`, `events`). No code generation (P6). Depends on `protocol_envelope` and `engine`.

```dart
final json = encodeCommand(command);   // Map<String, Object?>, ready for jsonEncode
final command = decodeCommand(json);   // throws ProtocolFormatException / UnknownTypeException
final event = decodeEvent(encodeEvent(event));
```

## Shape rules

- Every command and event is an object with `v` (shape version, 1), `type` (a stable name: the class name in lower camel case), `actor` and its own fields. Events also carry `visibility`.
- The encoding is **1:1 with the full event**. The stored log, the GM and the fixtures carry everything. What a player's copy leaves out (for example who else received a stat-gated broadcast) is the session's per-perspective projection, not the codec.
- Decoders ignore unknown extra fields and treat fields added later as optional, so frames written by an earlier minor keep decoding (01 §Compatibility decoding within a major). A newer `v` is refused with `ProtocolFormatException`; an unknown `type` throws `UnknownTypeException` (it carries the name, so the session can skip or refuse).
- Malformed input and values the engine refuses (a bad draw range, an empty alias set, a condition with dice) all surface as `ProtocolFormatException`.
- Formula values (terms, condition results) are plain JSON numbers and a whole-number double reads back as the integer, as in the engine. Integer fields (`amount`, `dc`, draw positions, attribute scores, die sides) accept integers only.
- Nesting deeper than 64 levels is refused, so hostile input cannot overflow the stack. Terms the engine would refuse (zero-sided dice, faces outside the die, empty sums, wrong operator arity) are refused, as is a `broadcastEvaluated` that is not `gmOnly`.
- Attribute and skill maps are written with sorted keys, so equal values always encode to the same text.
- Not checked here: duplicate JSON keys (the last wins) and empty ids; the session validates ids against the operation. `source: "entered"` decodes, because the field is reserved room for physical dice (concern 7); nothing produces it yet.
- Aliases in a visibility list are sorted, so the same event always encodes to the same text.

## Types

Commands: `startOperation`, `createAgent`, `requestAction`, `declineRequest`, `requireCheck`, `resolveCheck`, `applyCondition`, `clearCondition`, `applyDamage`, `applySanityLoss`, `broadcastToQualifying`.

Events: `operationStarted`, `agentCreated`, `actionRequested`, `requestDeclined`, `checkRequired`, `checkResolved`, `conditionApplied`, `conditionCleared`, `damageApplied`, `sanityLost`, `broadcastEvaluated`, `broadcastDelivered`.

Adding an engine command or event is a compile error here (the encoders switch exhaustively): add the encoder case, the decoder case, a sample in `test/support/samples.dart` and a fixture.

## Fixtures

`test/fixtures/v1/commands/<type>.json` and `events/<type>.json` hold one encoded sample per type. The tests check that today's encoder still writes exactly that file's text (byte for byte) and that the file still decodes to the sample. Once a major ships, its fixture folder is never edited: a shape change adds a field (additive) or a new `v`. A test checks there is one fixture per sample.

To refresh after an intended shape change, encode the samples from `test/support/samples.dart` with `JsonEncoder.withIndent('  ')` into the fixture files and review the diff.
