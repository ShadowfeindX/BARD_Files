# 04. Session (`packages/session`)

The session package is the runtime layer: it owns live operations, talks to transports and stores, enforces who may send what, and feeds the engine. It is pure Dart. Platform-specific pieces (sockets, Firebase, databases) are injected through interfaces.

## Coarse actors (Fixed structure, Proposed shape)

An actor here is a plain Dart object with a private mailbox (a queue) that handles one message at a time. Nothing else touches its state. This gives the ordering guarantees the event log needs without locks.

Actors are **not** isolates: isolates are not supported on Flutter web [V-13], and the work per message is small. An actor's interface does not change if a later version moves a heavy actor to an isolate on native platforms.

| Actor | Lives on | Owns |
|---|---|---|
| `OperationHost` | GM device | The canonical engine instance, RNG, `seq` counter, request dedupe, visibility filtering, settings |
| `OperationParticipant` | each player device (and GM's own player view if any) | A non-canonical engine instance fed by received events, pending requests, last seq |
| `ConnectionActor` | both ends, one per link | One transport link: framing, ping, backoff, hands decoded messages to its owner |
| `StoreActor` | each device | Appending events, writing snapshots, serving reads; wraps the `EventStore` interface |
| `RelayActor` | GM device, network-hosted only | Mirrors the GM's log to the backend (Realtime Database, through the backend port) and receives requests from it |
| `SessionDirectory` | each device | Which operations exist locally, opening/closing them, routing messages to the right actor |

Supervision is simple: `SessionDirectory` restarts a crashed `ConnectionActor`; a crashed `OperationHost` is reopened from the store (log + latest snapshot), which is always safe because state is a fold of the log.

## The operation loop (GM canonical, Fixed)

```
request(cmd) ──► OperationHost
                   1. authorize: is this sender allowed to issue this command? (session rule, not engine)
                   2. dedupe by request id
                   3. engine.decide(state, cmd, rng, ids)
                         ├─ Rejected → reply `rejected`
                         └─ Accepted(events)
                   4. assign seq; next = fold(evolve, events); narrate events
                      StoreActor.append(events + text lines + head snapshot of next), one durable write
                   5. state = next
                   6. for each participant: filter by visibility → send `events`
                   7. RelayActor mirrors (if network-hosted)
```

- Step 4 happens before step 6: an event is never broadcast before it is stored on the GM device.
- **Text log and head snapshot (Proposed).** Step 4 writes, in the same durable batch as the events, (a) the narrated text lines for those events and (b) the **head snapshot**: the state at the new last `seq`, replacing the previous head. A crash can therefore never leave events without text, or a log whose end state is unknown. Both exist because a major migration cannot use the old engine: the text log is what stays readable, and the head snapshot is the exact end state the migrator transforms ([05-migrator.md](05-migrator.md#archived-logs-fixed-ruled-by-r)). Periodic full snapshots for fast joins are unchanged.
- **Every event kind has a narrator** from the release that introduces it. The narrator is an exhaustive `switch` over the sealed `Event` family, so a missing case is a compile error [V-16].
- GM commands from the GM's own UI enter the same mailbox, so GM and player inputs are strictly ordered.
- **Authorization** lives here, not in the engine: "only the GM may `RequireCheck`", "a player may only `RequestAction` for an alias they control", "anonymous accounts cannot host". The engine stays about rules; the session is about people.

Participants:

```
`events` ──► OperationParticipant
               1. check seq continuity (gap → `resync`)
               2. StoreActor.append (local cache, for offline viewing)
               3. state = fold(evolve, events)
               4. notify listeners (view models)
```

Optimistic UI is allowed only for presentation (a "sent" spinner). A participant never applies its own guess to engine state.

## Interfaces the session depends on

```dart
abstract interface class Transport {        // one per kind: in-process, LAN, P2P, relay
  Stream<Link> incoming();                  // host side
  Future<Link> connect(Address address);    // client side
}

abstract interface class Link {
  Stream<Frame> get frames;
  Future<void> send(Frame frame);
  Future<void> close();
}

abstract interface class EventStore {       // persistence choice is Open (R); text/head parts Proposed
  Future<void> append(OperationId op, List<StoredEvent> events,
      List<TextLogLine> text, Snapshot head);                         // one durable write
  Stream<StoredEvent> read(OperationId op, {int fromSeq = 1});
  Future<void> putSnapshot(OperationId op, Snapshot snapshot);
  Future<Snapshot?> latestSnapshot(OperationId op);
  Future<Snapshot?> headSnapshot(OperationId op);                     // state at last seq
  Stream<TextLogLine> readText(OperationId op, {int fromSeq = 1});
}

/// One narrated log line (Proposed). Text is rendered per perspective at play
/// time, so the archive can show each viewer exactly what they saw.
final class TextLogLine {
  final int seq;
  final DateTime time;
  final Map<Audience, String> variants;  // gm, public, redacted, alias:<id>
}

abstract interface class Clock { DateTime now(); }
```

Every interface has an in-memory implementation in `session` itself, used by tests and by single-device play.

## Play modes

All modes run the same loop; they differ only in which `Transport` and whether a `RelayActor` is attached.

| Mode | Transport | Backend | Notes |
|---|---|---|---|
| Solo / prep | none | none | GM alone, building NPCs or testing. |
| In person, one device | in-process | none | Table shares the GM's screen; player views are panels on the same device. |
| In person, phones | LAN (or in-process + LAN) | none | GM device hosts; companion phones join on the local network. |
| LAN | LAN | none | Discovery on the local network; host must be a native app (see below). |
| P2P over internet | P2P | signaling only | Direct links between GM and players; needs signaling and NAT traversal [V-17]. |
| Network-hosted | relay | yes | Realtime Database relays and persists the log ([06-accounts-backend.md](06-accounts-backend.md#relay)). Players can join without reaching the GM directly. |
| Offline | any local | none | Signed-in accounts use the local cache; network-hosted operations resume relaying when online. |

**Web build (ruled by R):** a browser cannot run a socket server, because `dart:io` is not available on the web [V-12], so a GM on the web build cannot host LAN play. R accepted this. The web build is a lightweight client for people who have not installed the app yet and does not have full feature parity with native builds. Whether GM hosting is allowed on the web at all (relay/P2P only) or disallowed entirely is still open for R (item W1 in [09-open-decisions.md](09-open-decisions.md#open-items-for-r)). Native builds can host every mode.

## Reconnection and GM continuity

- A participant reconnects with `resync(lastSeq)` and receives the missing events or a fresh snapshot.
- Requests sent while disconnected stay queued locally and are delivered on reconnect; dedupe makes this safe.
- If the GM's device is lost mid-operation, the GM opens the operation on another device from the backend copy (network-hosted) or an exported log (local). There is no automatic GM failover: the GM is canonical by design, and handing canonicity to a player device would contradict that.

## Offline and sync semantics

Because the GM's log is the single ordered truth, there are no concurrent writers to merge. "Sync" is only:

1. Participants catching up to the GM's `seq`.
2. The GM device uploading its log to the backend when it regains connectivity (network-hosted mode).

The backend copy is a mirror, never a second authority. If the backend holds events the GM device does not (for example the GM resumed on a second device and then the first came back online), the first device must adopt the backend log before continuing; it never merges. The exact detection rule (compare last seq + hash of last event) is specified at implementation time.

## In-game phone

Players can send in-world text messages ("phone") that are forwarded to the GM (Fixed).

- Sending is a command: `SendPhoneMessage(fromAlias, to, body)` where `to` is the GM, an NPC entity, or another alias.
- The engine records `PhoneMessageSent` with visibility `aliases[sender, recipient-if-alias]` (the GM always sees it). Messages to an NPC go to the GM, who answers **as** that NPC with `SendPhoneMessage(fromNpc, ...)`.
- Because messages are events, they are part of the log, survive reconnects, and can be referenced by later documents.
- The companion app's phone screen is just a view over these events for one alias.

## Perspectives

The session exposes per-perspective state streams:

- **GM perspective:** full state, plus pending requests and hidden events.
- **Player perspective:** the filtered state for one alias.
- **Table perspective:** public-only, for a shared screen.

The main app's per-perspective panels (Fixed) subscribe to these. A single device can show several perspectives at once (GM screen plus a table panel) because they are separate streams over the same host.
