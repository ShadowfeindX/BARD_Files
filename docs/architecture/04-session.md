# 04. Session (`packages/session`)

The session package is the runtime layer: it owns live operations, talks to transports and stores, enforces who may send what, and feeds the engine. It is pure Dart. Platform-specific pieces (sockets, Firebase, databases) are injected through interfaces.

## Coarse actors (Fixed)

An actor here is a plain Dart object with a private mailbox (a queue) that handles one message at a time. Nothing else touches its state. This gives the ordering guarantees the event log needs without locks.

Actors are **not** isolates (P7, ruled by R 2026-10-20): they are single-threaded mailbox objects. Isolates are not supported on Flutter web [V-13], are too heavy for this job, and the work per message is small. If UI lag appears, it is solved another way, not by moving actors to isolates.

| Actor | Lives on | Owns |
|---|---|---|
| `OperationHost` | GM device | The canonical engine instance, RNG (the `xrandom` adapter, see below), `seq` counter, request dedupe, the GM review gate, visibility filtering, settings |
| `OperationParticipant` | each player device (and GM's own player view if any) | A non-canonical engine instance fed by received events, pending requests, last seq |
| `ConnectionActor` | both ends, one per link | One transport link: framing, ping, backoff, hands decoded messages to its owner |
| `StoreActor` | each device | Appending events, writing snapshots, serving reads; wraps the `EventStore` interface |
| `RelayActor` | GM device, network-hosted only | Mirrors the GM's log to the backend (Realtime Database, through the backend port) and receives requests from it |
| `SessionDirectory` | each device | Which operations exist locally, opening/closing them, routing messages to the right actor |

Supervision is simple: `SessionDirectory` restarts a crashed `ConnectionActor`; a crashed `OperationHost` is reopened from the store (log, text and head snapshot up to the last commit marker), which is always safe because state is a fold of the log.

## The operation loop (GM canonical, Fixed)

```
request(cmd) ──► OperationHost
                   1. authorize: is this sender allowed to issue this command? (session rule, not engine)
                   2. dedupe by request id
                   3. engine.decide(state, cmd, rng, ids)
                         ├─ Rejected → reply `rejected`
                         └─ Accepted(events), split into
                              rolls         (CheckResolved)
                              consequences  (damage, sanity loss, conditions, any category value)
                   4. rolls: go straight on to steps 5-8 (never gated)
                      consequences: held as a GM-only pending batch (GM review gate)
                         GM confirms or edits; an edit is recorded on the event (`overriddenFrom`);
                         auto-confirm skips the wait when the operation's setting says so
                   5. assign seq (rolls at once; consequences only once confirmed); next = fold(evolve, events); narrate events
                      StoreActor.append(events + text lines + head snapshot of next)
                         one transaction, then a commit marker in its own transaction
                   6. state = next
                   7. for each participant: filter by visibility → send `events`
                   8. RelayActor mirrors (if network-hosted)
```

In short: authorize → dedupe → decide → [rolls broadcast; consequences to GM review] → seq + narrate + store → filter → broadcast → relay.

- Storing comes before broadcast: an event is never broadcast before it is stored on the GM device.
- **GM review gate (F2 option A, Fixed; ruled by R 2026-10-20; covers rulebook decision 21).** The gate lives in `OperationHost`. Consequence events are held as a GM-only pending batch: nothing is sequenced, stored or broadcast for them yet, and only the GM perspective shows them. The GM confirms the batch or edits values first; an edit is recorded on the event (`overriddenFrom` holds the original value), so the log shows both. Only after confirmation are seq assigned, the events narrated, stored, filtered and broadcast.
- **Rolls are not gated.** `CheckResolved` is broadcast immediately and the GM never influences dice. Rolled faces are never altered; a GM edit to a consequence value sits beside the original.
- **Auto-confirm** is a per-operation GM setting. With it on, a pending batch is confirmed without waiting for the GM.
- **Text log and head snapshot (P12, Fixed).** Step 5 writes, in the same transaction as the events, (a) the narrated text lines for those events and (b) the **head snapshot**: the state at the new last `seq`, replacing the previous head. Narration and the head snapshot come after the GM confirms a consequence batch. Both exist because a major migration cannot use the old engine: the text log is what stays readable, and the head snapshot is the exact end state the migrator transforms ([05-migrator.md](05-migrator.md#archived-logs-fixed-ruled-by-r)). Periodic full snapshots for fast joins are unchanged.
- **Rolling autosave and durability (P12, 09-3, Fixed).** Non-web hosts write events, text and head snapshot to the local store in one sembast transaction per batch, then a **commit marker** in its own transaction. On open, everything after the last marker is discarded. One transaction alone is not crash-atomic: 19 of 100 hard kills tore a batch, because sembast 3.9.0 has no fsync or flush [V-31]. With the marker, 0 commits were lost over 100 kills on Linux and on Windows [V-31]. There is no power-loss or OS-crash protection in v1; R accepted this.
- **Head snapshot mirror.** The head snapshot is mirrored to the Realtime Database on a GM-configurable per-operation interval (proposed default 5 minutes), and also on pause, on close and before migration. Event and text batches still go to the Realtime Database every batch (relay). There is no web host (W1, below), so autosave concerns non-web hosts only.
- **Every event kind has a narrator** from the release that introduces it. The narrator is an exhaustive `switch` over the sealed `Event` family, so a missing case is a compile error [V-16].
- GM commands from the GM's own UI enter the same mailbox, so GM and player inputs are strictly ordered.
- **Authorization** lives here, not in the engine: "only the GM may `RequireCheck`", "a player may only `RequestAction` for an alias they control", "anonymous accounts cannot host". The engine stays about rules; the session is about people.

### RNG adapter (P5, Fixed)

The engine defines the `Rng` interface and stays SDK-only. The session package holds the adapter over `xrandom` 0.7.2, using `Xoshiro128pp` by class name (never the `Xrandom`/`Drandom`/`Qrandom` aliases) [V-28]. Its README marks `Xoshiro128pp` as working on JS; our own known-seed vectors must show the same sequence on native and web (P5 test requirement; not yet run). The version is pinned exactly, and known-seed test vectors are kept for native and web.

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

abstract interface class EventStore {       // sembast 3.9.0 behind this interface (09-3, Fixed)
  Future<void> append(OperationId op, List<StoredEvent> events,
      List<TextLogLine> text, Snapshot head);                         // one transaction, then a commit marker
  Stream<StoredEvent> read(OperationId op, {int fromSeq = 1});
  Future<void> putSnapshot(OperationId op, Snapshot snapshot);
  Future<Snapshot?> latestSnapshot(OperationId op);
  Future<Snapshot?> headSnapshot(OperationId op);                     // state at last seq
  Stream<TextLogLine> readText(OperationId op, {int fromSeq = 1});
}

/// One narrated log line (P12, Fixed). Text is rendered per perspective at play
/// time, so the archive can show each viewer exactly what they saw.
final class TextLogLine {
  final int seq;
  final DateTime time;
  final Map<Audience, String> variants;  // gm, public, redacted, alias:<id>
}

abstract interface class Clock { DateTime now(); }
```

Every interface has an in-memory implementation in `session` itself, used by tests and by single-device play.

**Persistence (09-3, Fixed; ruled by R 2026-10-20).** `EventStore` is implemented with `sembast` 3.9.0, plus `sembast_web` 2.4.6+1 for web player caches. There is one database file per operation, opened on demand, plus a small account/cache database. sembast loads a whole database file into memory, which is why a long operation is not kept in the same file as account data. `append` writes the batch in one transaction and then the commit marker in a second one; `open` discards everything after the last marker [V-31]. sembast is pinned exactly; the version is re-verified on pub.dev before it enters a pubspec (F5).

## Play modes

All modes run the same loop; they differ only in which `Transport` and whether a `RelayActor` is attached.

**Transport build order (09-4, Fixed; ruled by R 2026-10-20):** in-process, LAN, Realtime Database relay, P2P. The packages for LAN and P2P (`web_socket_channel`, `bonsoir`, `flutter_webrtc`) are not approved yet; each goes to R when its transport is scheduled.

| Mode | Transport | Backend | Notes |
|---|---|---|---|
| Solo / prep | none | none | GM alone, building NPCs or testing. |
| In person, one device | in-process | none | Table shares the GM's screen; player views are panels on the same device. |
| In person, phones | LAN (or in-process + LAN) | none | GM device hosts; companion phones join on the local network. |
| LAN | LAN | none | Discovery on the local network; host must be a native app (see below). |
| P2P over internet | P2P | signaling only | Direct links between GM and players; needs signaling and NAT traversal [V-17]. Built last. |
| Network-hosted | relay | yes | Realtime Database relays live play; finished operations are archived to Firestore (FS1, FS3) ([06-accounts-backend.md](06-accounts-backend.md#relay)). Players can join without reaching the GM directly. |
| Offline | any local | none | Signed-in accounts use the local cache; network-hosted operations resume relaying when online. |

**Web build (W1, Fixed for now; ruled by R 2026-10-20):** the web build is player-only: no GM hosting. A browser cannot run a socket server, because `dart:io` is not available on the web [V-12], and R ruled that the web build is a lightweight client for people who have not installed the app yet, without full parity with native builds. Web player caches use `sembast_web`. Revisiting this with onboarding in mind is Pending D: see [09-open-decisions.md](09-open-decisions.md#pending-d). Native builds can host every mode.

**Physical dice (concern 7).** A per-operation GM setting, off by default, would allow players to enter faces of physical dice. Without it, entered faces are refused, so the GM never mistakes player-entered values for client rolls. The session only reserves the `source` field on `CheckResolved` (`rng` | `entered`, plus who entered). The feature itself is Pending D: see [09-open-decisions.md](09-open-decisions.md#pending-d).

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
- On the RTDB relay, the draft uses a phone box per player (`phone/$uid/$push`), because a sender cannot list a shared list they only partly own [V-38] (P10c, Proposed); see [06-accounts-backend.md](06-accounts-backend.md#realtime-database-model-live-play).

## Perspectives

The session exposes per-perspective state streams:

- **GM perspective:** full state, plus pending requests, hidden events and the pending consequence batch awaiting review (visible to the GM only).
- **Player perspective:** the filtered state for one alias.
- **Table perspective:** public-only, for a shared screen.

The main app's per-perspective panels (Fixed) subscribe to these. A single device can show several perspectives at once (GM screen plus a table panel) because they are separate streams over the same host.
