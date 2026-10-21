# Session

`packages/session` is the runtime: the GM's `OperationHost`, a player's `OperationParticipant`, and the interfaces they stand on (04-session.md). It imports the wire types through `protocol`, which re-exports `protocol_envelope`.

## Pieces

| File | Holds |
|---|---|
| `operation_host.dart` | `OperationHost`: authorize, dedupe, decide, hold consequences for review, stamp `seq`, store, filter, broadcast. `submit` (GM), `confirmPending`, `openView`, `listen` |
| `operation_participant.dart` | `OperationParticipant`: non-canonical engine, requests with retry, resync on gaps |
| `entries.dart` | Wire entries and `PerspectiveFeed` (applies entries in order, tolerates duplicates, reports gaps) |
| `perspective.dart` | `Perspective` and `deliveryFor` (visibility to full/redacted/hidden) |
| `identity.dart`, `authorizer.dart` | `Principal`, `IdentityVerifier`, `Admission`, `Authorizer`, `SessionRejection` codes |
| `event_store.dart` | `EventStore` interface, `InMemoryEventStore` |
| `transport.dart`, `in_memory_transport.dart`, `connection_actor.dart` | `Transport`/`Link`, the in-process network (with a frame filter for tests), envelope framing |
| `mailbox.dart`, `clock.dart` | The one-at-a-time queue, `Clock` and `FakeClock` |
| `xoshiro_rng.dart` | The production `Rng` |

## Rules the host keeps

- **Store before broadcast.** `_commit` evolves a copy, appends, and only then replaces state and sends.
- **Identity comes from `hello`.** The `IdentityVerifier` decides who a link is and whether the agent is anonymous; later frames are authorized on that, never on `from`.
- **Entity ids never repeat after a reopen.** The id source restarts at the larger of one past the highest `e<N>` in the replayed state and the counter stored with the head snapshot.
- **RNG draws are never reused.** After every `decide`, a changed draw count is saved with `saveRngDrawCount`; every append carries it too. A reopen resumes at the larger of that and the state's own count.
- **A retried request never decides twice.** The host remembers `(agent, request id)` per answered request, including across a reopen (the stored event records its origin). Refused requests are not stored, so a retry after a reopen is decided again, to the same refusal.
- **GM identity is checked.** A verified identity flagged `isGm` is admitted only if it is the operation's GM; everything else must have an alias.

## Plugging in

- **Engine codec.** `EngineCodec` (in `protocol`) turns commands, events and state into JSON. Until row 6 supplies it, tests use `test/support/test_codec.dart`.
- **Consequence gate.** The host holds every event that is a `Consequence` (the engine's marker) until `confirmPending` or the operation's auto-confirm setting; rolls are never consequences, so they are never held. A review `edit` must return the same consequence type for the same entity, actor and visibility, or `confirmPending` throws and the batch stays pending.
- **What players receive.** `projectFor` shapes the copy of an event a player or the table gets: `overriddenFrom` is dropped and a multi-alias event is narrowed to the viewer's alias. The store and the GM keep the whole event. Add a case when a new event can address several aliases or carries GM-only detail.
- **Text log.** Each commit stores the engine `Narrator`'s lines as `gm`, `public`, `redacted` and `alias:<id>` variants.
- **Authorization.** `DefaultAuthorizer(playerMay: ...)` lists the commands players may send.
- **Transports.** Implement `Transport`/`Link`; frames are strings.

## Open

- Held consequence batches are in memory: closing or reopening the host loses them without a message. Whether they should survive a reopen is for R.
- The host stores text-log lines but never sends a `textlog` message (that message is for archived text from earlier engine majors).
- `projectFor` covers the events that can address several aliases today (`BroadcastDelivered`, `CheckRequired`, `CheckResolved`) and the three that carry `overriddenFrom`; a new event with either property needs a case.
- The host never decodes a stored snapshot: it replays the log. Snapshots for fast joins come later.
- Admission (invites, bans, locks, the anonymous alias map) lives in memory: a reopened host starts empty until the account layer repopulates it.
- Frames are sent one link at a time inside the commit, so a slow link delays the loop.
- `Welcome` carries no events; the host sends them in `events` frames right after it.
- No narrator, ping scheduling, reconnect backoff or participant-side store yet.
- Co-recipients stay hidden (R, 2026-10-21): `projectFor` narrows `BroadcastDelivered` to the viewer.
- `hidden` entries keep `seq` consecutive per recipient; the RTDB relay stores events per audience, so row 15 must decide how a player reads a gapless sequence from it.
