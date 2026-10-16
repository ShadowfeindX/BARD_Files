# 03. Protocol (`packages/protocol`)

The protocol package defines every message that crosses a process or device boundary, and how it is encoded. It is pure Dart, depends only on `engine` (for command and event codecs), and knows nothing about sockets, Firebase or Flutter.

One protocol serves every transport: in-process, LAN, P2P, and backend relay. A transport only moves opaque frames.

## Envelope (Proposed)

```json
{
  "p": 1,                         // protocol major
  "e": "1.4.0",                   // sender's engine version
  "op": "op_01J...",              // operation id
  "seq": 1042,                    // GM-assigned sequence (events only)
  "from": "alias_... | gm",       // logical sender
  "type": "events",
  "body": { ... }
}
```

- Encoding is JSON via `dart:convert` (no extra dependency). A binary codec can be added later behind the same `Codec` interface if size ever matters.
- Every engine command and event has a stable `type` string and a versioned JSON shape defined next to its Dart class. Codecs are hand-written `toJson` / `fromJson` (Proposed), consistent with CLAUDE.md §10's "no hidden code generation without a doc entry". If R prefers generated serializers, that is a new dependency and goes to R.

## Messages

| Type | Direction | Purpose |
|---|---|---|
| `hello` | client → GM | Who I am (agent id, alias id, auth proof if any), engine version, protocol major, last seq I have. |
| `welcome` | GM → client | Accepted. Snapshot (filtered for this perspective) and/or events from the client's last seq. Operation settings visible to the client. |
| `refused` | GM → client | Version mismatch, not invited, alias locked elsewhere, banned. Machine-readable reason. |
| `request` | client → GM | A command for the GM engine to decide. Carries a client-generated request id for idempotency. |
| `rejected` | GM → client | The GM engine (or GM) rejected a request. References the request id. |
| `events` | GM → clients | One or more events with consecutive `seq`, already filtered for the recipient. |
| `resync` | client → GM | "I have up to seq N" after a gap or reconnect. |
| `presence` | both | Online/away/typing; never part of the event log. |
| `ping` / `pong` | both | Liveness. |

There is no message by which a client sends an *event*. Only the GM produces events (Fixed authority model).

## Ordering and delivery

- The GM's session assigns `seq` strictly increasing per operation, starting at 1. It is the order of truth.
- Clients apply events only in `seq` order. A gap triggers `resync`.
- Requests are at-least-once from the client; the GM deduplicates by request id, so a retried request never rolls twice.
- Transports may reorder or duplicate frames; the protocol tolerates both.

## Visibility and perspectives

Each event carries a `visibility`:

| Visibility | Delivered to |
|---|---|
| `public` | everyone in the operation |
| `gm` | GM only (hidden rolls, NPC secrets, seed draws) |
| `aliases[...]` | the listed aliases and the GM (private handouts, a phone message) |
| `redacted` | everyone, but with a redacted body ("the GM rolled something") |

The GM's session filters before sending. A player's engine therefore holds a **partial** state built from what that player may see. Read models in the engine must handle missing entities/components gracefully (for example, an unknown NPC's Health shows as unknown).

The filtering is about immersion and fairness between honest clients, not security. With no anti-cheat (Fixed), a player can always inspect what their own device received, which is exactly what filtering limits.

## Version negotiation

On `hello`:

1. **Protocol major** must match the GM's, else `refused(protocolMismatch)`.
2. **Engine major** must match the operation's, else `refused(engineMajorMismatch)`. Cross-major moves happen only through the migrator.
3. **Engine minor/patch**: the client must be at least the version the operation's log requires (the highest `e` on any event so far). Lower: `refused(updateRequired)`. This guarantees no client meets an event type it does not understand.
4. Pack: clients receive pack values they need via the snapshot or by fetching the pinned `(id, version, contentHash)` from the pack source. A client never uses a different pack version than the operation.

## Snapshots

A snapshot is `OperationState` at a given `seq`, serialized with the engine's schema and filtered per perspective. It lets late joiners and reconnecting clients skip replaying a long log. Snapshots are a cache: the event log stays the source of truth.

## Size

Firestore caps a document at 1 MiB [V-7]. When the backend relay is Firestore, the session batches events into documents well under that limit and stores snapshots in chunks. Other transports have no such cap but use the same batching for simplicity.

## Testing

Round-trip tests for every message and every engine command/event, plus fixture files per protocol and engine version kept under `packages/protocol/test/fixtures/` so old logs keep decoding. See [08-testing.md](08-testing.md#protocol).
