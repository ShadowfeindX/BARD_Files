# 04. Session (`packages/session`)

The session package is the runtime layer: it owns live episodes, talks to transports and stores, enforces who may send what, and feeds the engine. It is pure Dart. Platform-specific pieces (sockets, Firebase, databases) are injected through interfaces.

## Coarse actors

An actor here is a plain Dart object with a private mailbox (a queue) that handles one message at a time. Nothing else touches its state. This gives the ordering guarantees the event log needs without locks.

Actors are **not** isolates: they are single-threaded mailbox objects. Isolates are not supported on Flutter web [V-13], are too heavy for this job, and the work per message is small.

| Actor | Lives on | Owns |
|---|---|---|
| `EpisodeHost` | GM device | The canonical engine instance, RNG (the `xrandom` adapter, see below), `seq` counter, request dedupe, the GM review gate, visibility filtering, settings |
| `EpisodeParticipant` | each player device (and GM's own player view if any) | A non-canonical engine instance fed by received events, pending requests, last seq |
| `ConnectionActor` | both ends, one per link | One transport link: framing and liveness pings (built); hands decoded messages to its owner. Reconnect backoff is the participant's `Reconnector` (built) |
| `StoreActor` (planned, 10 §5) | each device | Appending events, writing snapshots, serving reads; wraps the `EventStore` interface |
| `RelayActor` (planned, 10 §5) | GM device, network-hosted only | Mirrors the GM's log to the backend (Realtime Database, through the backend port) and receives requests from it |
| `SessionDirectory` (planned, 10 §5) | each device | Which episodes exist locally, opening/closing them, routing messages to the right actor |

As built: `EpisodeHost`, `EpisodeParticipant`, `ConnectionActor` (framing and liveness pings) and the participant's `Reconnector` (backoff, resume from `lastSeq`); the other three actors are planned (10 §5). Supervision is simple (planned with `SessionDirectory`): `SessionDirectory` restarts a crashed `ConnectionActor`; a crashed `EpisodeHost` is reopened from the store (log, text and head snapshot up to the last commit marker), which is always safe because state is a fold of the log.

## The episode loop (GM canonical)

```
request(cmd) ──► EpisodeHost
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
                         auto-confirm skips the wait when the episode's setting says so
                   5. assign seq (rolls at once; consequences only once confirmed); next = fold(evolve, events); narrate events
                      store append (as built: EpisodeHost calls EventStore.append; StoreActor planned) (events + text lines + head snapshot of next)
                         one transaction, then a commit marker in its own transaction
                   6. state = next
                   7. for each participant: filter by visibility → send `events`
                   8. RelayActor mirrors (planned; if network-hosted)
```

In short: authorize → dedupe → decide → [rolls broadcast; consequences to GM review] → seq + narrate + store → filter → broadcast → relay.

- Storing comes before broadcast: an event is never broadcast before it is stored on the GM device.
- **GM review gate.** The gate lives in `EpisodeHost`. Consequence events are held as a GM-only pending batch: nothing is sequenced, stored or broadcast for them yet, and only the GM perspective shows them. The GM confirms the batch or edits values first; an edit is recorded on the event (`overriddenFrom` holds the original value), so the log shows both. Only after confirmation are seq assigned, the events narrated, stored, filtered and broadcast.
- **Rolls are not gated.** `CheckResolved` is broadcast immediately and the GM never influences dice. Rolled faces are never altered; a GM edit to a consequence value sits beside the original.
- **Auto-confirm** is a per-episode GM setting, separate from the setting for requests between sittings ([below](#settings-resolution)). It is an `EpisodeSettings` field, default off (Proposed; open: [auto-confirm default](10-waiting-on-d.md#auto-confirm-default)), set by the GM per episode. With it on, a pending batch is confirmed without waiting for the GM.
- **Death goes through the gate.** A character reaching 0 Health dies as part of the confirmed damage batch, so the Handler can edit the damage before the death is recorded. The Handler's own `KillCharacter` command is not gated ([01](01-engine.md#rulebook-values-the-engine-uses), [planned code changes](01-engine.md#planned-code-changes)). (Planned; 01 'Death and control' row.)
- **Text log and head snapshot.** Step 5 writes, in the same transaction as the events, (a) the narrated text lines for those events and (b) the **head snapshot**: the state at the new last `seq`, replacing the previous head. Narration and the head snapshot come after the GM confirms a consequence batch. Both exist because a major migration cannot use the old engine: the text log is what stays readable, and the head snapshot is the exact end state the migrator transforms ([05-migrator.md](05-migrator.md#archived-logs)). Planned: periodic full snapshots for fast joins (store methods to be added; 10 §5).
- **Rolling autosave and durability.** Non-web hosts write events, text and head snapshot to the local store in one sembast transaction per batch (planned: the `sembast` 3.9.0 store, 10 §5; today only `InMemoryEventStore` exists), then a **commit marker** in its own transaction. On open, everything after the last marker is discarded. One transaction alone is not crash-atomic: 19 of 100 hard kills tore a batch, because sembast appends a transaction's records as separate lines with nothing marking the batch complete [V-31]. sembast 3.9.0 also calls no fsync, which matters for power loss, not for a process kill [V-31]. With the marker, 0 commits were lost over 100 kills on Linux and on Windows [V-31]. There is no power-loss or OS-crash protection in v1.
- **Head snapshot mirror.** The head snapshot is mirrored to the Realtime Database on a GM-configurable per-episode interval (proposed default 5 minutes; open: [S-5](09-open-decisions.md#s-5-head-snapshot-mirror-interval)), and also on pause, on close and before migration. Event and text batches still go to the Realtime Database every batch (relay). (Planned; 10 §5 'RTDB live relay'.) There is no web host (see [Play modes](#play-modes)), so autosave concerns non-web hosts only.
- **Every event kind has a narrator** from the release that introduces it. The narrator is an exhaustive `switch` over the sealed `Event` family, so a missing case is a compile error [V-16].
- GM commands from the GM's own UI enter the same mailbox, so GM and player inputs are strictly ordered.
- **Authorization** lives here, not in the engine: "only the GM may `RequireCheck`", "a player may only `RequestAction` for an alias they control", "anonymous accounts cannot host". The engine stays about rules; the session is about people.

### Settings resolution

(Planned; 10 §5 'Campaign-level members and rules'; only `EpisodeSettings` is built.) Game settings (physical dice allowed, Handler-facing switches) have a base at the **campaign** (campaign base is set; D to confirm: [FE-L2](10-waiting-on-d.md#fe-l2)), which also owns the pack version pin. Each new mission starts as a copy of the base (or of another mission) and may override it. The resolved value is the mission's override, else the campaign base; the host reads the resolved values when it opens an episode and keeps them in the episode's `EpisodeSettings` ([01](01-engine.md#commands-and-events)). Join links, the roster and listings stay at the campaign ([12](12-firestore-collections.md#campaigns-operations-and-episodes)). The pack pin stays at the campaign because characters carry across missions and a different pin per mission could change their numbers.

The consequence auto-confirm is not one of these: it stays a per-episode setting. The auto-confirm setting for requests made between sittings (purchases and contact releases, see [Requests between sittings](#requests-between-sittings)) has its default at the campaign and can be set per mission. These features are available only once an alias has been added to a mission and is connected to an active GM host.

### Names in the log

(Planned: not built; see 10 §5 'Remaining engine systems' (`GmSystem`) and the Name rule row [N1-R2](10-waiting-on-d.md#n1-r2).) How lines are produced is open ([N1-R1](10-waiting-on-d.md#n1-r1), [N1-R2](10-waiting-on-d.md#n1-r2), [N1-R4](10-waiting-on-d.md#n1-r4), [N1-R5](10-waiting-on-d.md#n1-r5)).

- **Before a reveal.** The log names a character by a short description the Handler types ("the man in the grey coat"); with none, numbered unknowns ("Unknown 1", "Unknown 2").
- **Reveals.** The Handler can reveal a cover name first and the true name later, and can reveal a name to some agents only. A reveal is not taken back; the Handler can only give a new label from then on.
- **Agents.** Players' agents know each other's names from the start; the Handler can keep an agent a stranger.
- **Phone.** An unknown number shows as "Unknown number" until the Handler releases the contact; the Handler can set a label.
- **Earlier lines.** After a reveal, the lines of the current episode show the new name; archived logs do not change. A revealed name stays known in later episodes unless the Handler sets a new name.

Proposed mechanism (open: [N1-R2](10-waiting-on-d.md#n1-r2), [N1-R5](10-waiting-on-d.md#n1-r5), [R6](10-waiting-on-d.md#r6)): a Handler command `RevealName`, an event `NameRevealed` and a component `KnownAs` in `GmSystem`; the narrator takes a viewer and resolves every name through one function; the host regenerates the current episode's stored text on a reveal or at episode end, and leaves archived text untouched. Reveals are not consequence events and are not gated. Verification test: for every perspective, the host's stored variant for each `seq` equals what a participant on that perspective narrates from its own feed.

### RNG adapter

The engine defines the `Rng` interface and stays SDK-only. The session package holds the adapter over `xrandom` 0.7.2, using `Xoshiro128pp` by class name (never the `Xrandom`/`Drandom`/`Qrandom` aliases) [V-28]. Its README marks `Xoshiro128pp` as working on JS; our own known-seed vectors must show the same sequence on native and web. The vectors are in `packages/session/test/xoshiro_rng_test.dart`, and CI runs them on the VM and, with `dart test -p node` in `packages/session`, on Node.js.

Participants:

```
`events` ──► EpisodeParticipant
               1. check seq continuity (gap → `resync`)
               2. StoreActor.append (planned; local cache, for offline viewing)
               3. state = fold(evolve, events)
               4. notify listeners (view models)
```

Optimistic UI is allowed only for presentation (a "sent" spinner). A participant never applies its own guess to engine state.

## Interfaces the session depends on

```dart
abstract interface class Transport {        // one per kind: in-process, LAN, P2P, relay
  Stream<Link> incoming();                  // host side
  Future<Link> connect(Address address);    // client side; Address wraps a String
}

abstract interface class Link {
  Stream<String> get frames;                // frames are opaque strings
  Future<void> send(String frame);
  Future<void> close();
}

// As built in packages/session/lib/src/event_store.dart. Planned: a sembast 3.9.0
// store behind this interface (10 §5); today only InMemoryEventStore exists.
abstract interface class EventStore {
  Future<void> append(String episodeId, List<StoredEvent> events,
      List<TextLogLine> text, HeadSnapshot head);                     // planned sembast store: one transaction, then a commit marker
  Stream<StoredEvent> read(String episodeId, {int fromSeq = 1});
  Stream<TextLogLine> readText(String episodeId, {int fromSeq = 1});
  Future<HeadSnapshot?> headSnapshot(String episodeId);               // state at last seq
  Future<void> saveRngDrawCount(String episodeId, int drawCount);     // draws made without stored events
  Future<int> rngDrawCount(String episodeId);
  // Planned (periodic full snapshots; 10 §5), not in event_store.dart today:
  // Snapshot is the protocol wire type (protocol_envelope), not HeadSnapshot.
  Future<void> putSnapshot(String episodeId, Snapshot snapshot);
  Future<Snapshot?> latestSnapshot(String episodeId);
}

/// One narrated log line. Text is rendered per perspective at play
/// time, so the archive can show each viewer exactly what they saw.
final class TextLogLine {
  final int seq;
  final DateTime time;
  final Map<String, String> variants;  // keys: gm, public, redacted, alias:<id>
}

abstract interface class Clock { DateTime now(); }
```

Every interface has an in-memory implementation in `session` itself, used by tests and by single-device play.

**Persistence.** Planned (10 §5; today only `InMemoryEventStore` exists): `EventStore` is implemented in `backend` with `sembast` 3.9.0, plus `sembast_web` 2.4.6+1 for web player caches. There is one database file per episode, opened on demand, plus a small account/cache database. sembast loads a whole database file into memory, which is why a long episode is not kept in the same file as account data. `append` writes the batch in one transaction and then the commit marker in a second one; `open` discards everything after the last marker [V-31]. sembast is pinned exactly; the version is re-verified on pub.dev before it enters a pubspec.

### Event entries

The engine event does not carry its own `seq`, and a recipient must see every `seq` to check continuity while some events are not theirs. So the host wraps each event for each recipient (`packages/session/lib/src/entries.dart`):

| Entry | Sent when | JSON |
|---|---|---|
| full | the recipient may read the event | `{"seq": n, "event": {...}}`, plus `"req": "<requestId>"` for the agent whose request caused it (this is the acknowledgement of a request; redacted and hidden entries carry it too) |
| redacted | visibility `redacted` | `{"seq": n, "redacted": true}` |
| hidden | `gm`, or `aliases[...]` without the recipient | `{"seq": n, "hidden": true}` |

An entry has exactly one of `event`, `redacted: true` or `hidden: true`; anything else is malformed. A participant applies entries only in `seq` order, skips ones it has, and sends `resync(lastSeq)` on a gap or a malformed frame. Redacted and hidden entries advance `lastSeq` without evolving state. The hidden entry shows a player that a GM-only event exists (not what it is), so every recipient sees every `seq` and the consecutive-`seq` check holds. Showing that a GM event exists is accepted on the wire.

The host sends at most 200 entries per `events` frame and starts a new frame early when the next entry would take the frame past the protocol's frame limit, less the measured envelope header ([03](03-protocol.md#envelope)). So that one entry always fits, the host refuses (`tooLarge`) a command whose encoded event would exceed `maxEventLength` (the frame limit less room for the header, `seq`, flags and `req`) before anything is stored, and rejects a request id longer than 256 UTF-16 units once JSON-encoded (an escaped control character counts 6). A Handler's edit of a held consequence is measured again and refused the same way, so the batch stays pending. A participant refuses locally a request that would not fit in one frame.

Authorization uses the identity verified at `hello` (`IdentityVerifier`), never the envelope `from` or the hello's `kind`.

## Play modes

All modes run the same loop; they differ only in which `Transport` and whether a `RelayActor` is attached.

**Transport build order:** in-process, LAN, Realtime Database relay, P2P. The packages for LAN and P2P (`web_socket_channel`, `bonsoir`, `flutter_webrtc`) are not added before R approves them (open: [S-6](09-open-decisions.md#s-6-transport-packages)); each goes to R when its transport is scheduled.

| Mode | Transport | Backend | Notes |
|---|---|---|---|
| Solo / prep | none | none | GM alone, building NPCs or testing. |
| In person, one device | in-process | none | Table shares the GM's screen; player views are panels on the same device. |
| In person, phones | LAN (or in-process + LAN) (planned; S-6) | none | GM device hosts; companion phones join on the local network. |
| LAN | LAN (planned; S-6) | none | Discovery on the local network; host must be a native app (see below). |
| P2P over internet | P2P (planned; S-6) | signaling only | Direct links between GM and players; needs signaling and NAT traversal [V-17]. Built last. |
| Network-hosted (planned) | relay | yes | Realtime Database relays live play; finished episodes are archived to Firestore ([06-accounts-backend.md](06-accounts-backend.md#relay)). Players can join without reaching the GM directly. |
| Offline | any local | none | Signed-in accounts use the local cache; network-hosted episodes resume relaying when online (planned; 10 §5 'Offline account cache and session outbox'). |

**Web build:** the web build is player-only: no GM hosting. A browser cannot run a socket server, because `dart:io` is not available on the web [V-12], and the web build is a lightweight client for people who have not installed the app yet, without full parity with native builds. Web player caches use `sembast_web` (planned). Native builds can host every mode.

**Physical dice.** A GM setting, off by default, would allow players to enter faces of physical dice. Without it, entered faces are refused, so the GM never mistakes player-entered values for client rolls. The engine reserves the `source` field on `CheckResolved` (`rng` | `entered`, plus who entered). The feature is not built (workstream row in [10 §5](10-waiting-on-d.md#5-workstream-rows-still-to-schedule)), and the setting is resolved like the others ([above](#settings-resolution)).

## Reconnection and GM continuity

- A participant reconnects with `resync(lastSeq)` and receives the missing events or a fresh snapshot (planned; 10 §5 'RTDB live relay' and 'Periodic full snapshots for fast joins'; today resync sends entries only).
- Requests sent while disconnected stay queued locally and are delivered on reconnect; dedupe makes this safe.
- If the GM's device is lost mid-episode, the GM opens the episode on another device from the backend copy (network-hosted) or an exported log (local). There is no automatic GM failover: the GM is canonical by design, and handing canonicity to a player device would contradict that (planned; 10 §5 'RTDB live relay' and 'Periodic full snapshots for fast joins'; today resync sends entries only and there is no log export; 10 §5 'Local log export and resume from export').

## Diagnostics

A `DiagnosticLog` in the session layer records what the actors did, in order, apart from the game log. `EpisodeHost` and `EpisodeParticipant` take one optionally (`diagnostics:`); without one they record nothing. Each machine keeps its own log and keeps all of it for the life of the process. On the host machine a `DiagnosticFileSink` (in `backend`) also appends each entry to a `.jsonl` file beside the episode's store file, so the log survives a crash.

An entry has a category (`lifecycle`, `network`, `request`, `store`, `error`), a dotted kind and a few fields. Entries describe the machinery and never contents: link opened or closed, hello joined or refused with a reason, a request committed, held or refused (command type and `seq`s only), a batch committed, a gap detected, a resync requested or served, a store write that failed, a malformed frame. Every entry passes through a `Redactor` first:

- Message text, notes, names, join codes and auth proofs are replaced by `[redacted]`.
- Agent, alias and request ids become a stable pseudonym such as `agent-3fa9c1d2`: the same id gives the same pseudonym within one log, and the salt differs between logs.
- Any other string is cut to 80 characters; objects are not kept.

**Report bundle.** `ReportBundleBuilder` turns a session into a `ReportBundle`, a set of named files, and `backend` writes it into a local folder (`bard-report-<episode>-<time>/`) that the tester sends by hand; nothing is uploaded. Each kind of log is its own file and none is merged into another:

| File | Holds |
|---|---|
| `environment.json` | app, engine and protocol versions; OS; Flutter and Dart versions; the pack pin |
| `settings.json` | settings in force (snapshot interval, auto-confirm, transport), redacted |
| `diagnostic-log.jsonl` | the whole diagnostic log |
| `network-trace.jsonl` | the `network` entries only: connect, disconnect, resync, gaps, with `seq`s |
| `recent-errors.jsonl` | the last 50 `error` and `store` entries |
| `store-health.json` | store health, when the store provides it |
| `game-log.jsonl`, `text-log.jsonl`, `snapshot.json` | the episode's events, narrated lines and latest head snapshot, enough to reproduce the state |
| `notes.json` | the Handler's NPC notes, only when the Handler ticks "include notes" |
| `manifest.json` | what the bundle holds |

The game log holds what players and the Handler did, with real agent and alias ids (the host needs them to resume), and the text log holds narrated lines and names. A bundle is for us and the tester, not for publishing. Only the diagnostic files are redacted.

## Offline and sync semantics

Because the GM's log is the single ordered truth, there are no concurrent writers to merge. "Sync" is only:

1. Participants catching up to the GM's `seq`.
2. The GM device uploading its log to the backend when it regains connectivity (network-hosted mode).

The backend copy is a mirror, never a second authority. If the backend holds events the GM device does not (for example the GM resumed on a second device and then the first came back online), the first device must adopt the backend log before continuing; it never merges. The exact detection rule (proposed: compare last seq + hash of last event) is open: [S-10](09-open-decisions.md#s-10-duplicate-and-gap-detection-between-the-host-and-the-backend-copy).

## Requests between sittings

(Planned; open: [Q5](10-waiting-on-d.md#q5).) A request a player makes outside a live episode (a store purchase, or a contact release asking the Handler to hand over an NPC's details) waits for the Handler to approve, because the Handler may not be online. Auto-confirm for these is a setting with its base at the campaign and a per-mission override ([above](#settings-resolution)). Where the waiting requests are stored, and whether purchases may ever auto-confirm, are open ([Q5](10-waiting-on-d.md#q5)); the working assumption is that purchases are not auto-confirmed, since the GM review gate covers consequence events only.

## In-game phone

Players can send in-world text messages ("phone") that are forwarded to the GM.

- Sending is a command, `SendPhoneMessage(from, to, text)` (names and fields Proposed, open: [S-2](09-open-decisions.md#s-2-sendphonemessage-names-and-fields)). `from` and `to` are a party: the Handler, an alias, or a GM-run entity (an entity with no owning alias). A player sends as their own alias to the Handler, a GM-run entity or another alias; the Handler sends as themselves or as a GM-run entity, to an alias. The engine checks that the sender matches the command's actor, that both parties exist, and that the text is 1 to 2,000 UTF-16 code units (the relay rules' cap). Whether an account may send at all (anonymous accounts may not, [06](06-accounts-backend.md)) is the session's authorization, not the engine's.
- The engine records `PhoneMessageSent` with visibility `aliases[sender, recipient-if-alias]`; the session's projection always gives the Handler every event, so the GM sees it too. Messages to a GM-run entity go to the Handler, who answers **as** that entity with `SendPhoneMessage(from: entity, ...)`. Clearing the relay's phone box when the operation ends is a function's job after the archive is written; the engine has no such event. The phone **contact list** belongs to the campaign and the phone box messages to the operation.
- Because messages are events, they are part of the log, survive reconnects, and can be referenced by later documents.
- The companion app's phone screen is just a view over these events for one alias (planned; 10 §5 'Companion app').
- On the RTDB relay (planned), each player has a phone box (`phone/$uid/$push`) holding both the player's and the GM's messages, because a sender cannot list a shared list they only partly own [V-38]. The box is cleared when the operation ends; that step is not built yet. See [06-accounts-backend.md](06-accounts-backend.md#realtime-database-model-live-play).

## Perspectives

The session exposes per-perspective state streams:

- **GM perspective:** full state, plus pending requests, hidden events and the pending consequence batch awaiting review (visible to the GM only).
- **Player perspective:** the filtered state for one alias.
- **Table perspective:** public-only, for a shared screen.

The main app's per-perspective panels subscribe to these. A single device can show several perspectives at once (GM screen plus a table panel) because they are separate streams over the same host.
