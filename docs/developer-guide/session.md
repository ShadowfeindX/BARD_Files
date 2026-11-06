# Session

`packages/session` is the runtime: the GM's `EpisodeHost`, a player's `EpisodeParticipant`, and the interfaces they stand on (04-session.md). It imports the wire types through `protocol`, which re-exports `protocol_envelope`.

## Pieces

| File | Holds |
|---|---|
| `episode_host.dart` | `EpisodeHost`: authorize, dedupe, decide, hold consequences for review, stamp `seq`, store, filter, broadcast. `submit` (GM), `confirmPending`, `openView`, `listen` |
| `episode_participant.dart` | `EpisodeParticipant`: non-canonical engine, requests with retry, resync on gaps |
| `entries.dart` | Wire entries and `PerspectiveFeed` (applies entries in order, tolerates duplicates, reports gaps) |
| `perspective.dart` | `Perspective` and `deliveryFor` (visibility to full/redacted/hidden) |
| `identity.dart`, `authorizer.dart` | `Principal`, `IdentityVerifier`, `Admission`, `Authorizer`, `SessionRejection` codes |
| `event_store.dart` | `EventStore` interface, `InMemoryEventStore`, JSON forms of the stored types |
| `store_actor.dart` | `StoreActor`: every store call through one mailbox; mirrors the head through a `HeadMirrorSink` once `snapshotInterval` has passed (default 5 minutes, from the host machine's `HostSettingsStore`) and on `mirrorHead` for pause, close and migration |
| `episode_export.dart` | `EpisodeExport` (one file: log, text lines, latest head, RNG draw count), `exportEpisode`, `importEpisode` (into an empty store only) |
| `transport.dart`, `in_memory_transport.dart`, `connection_actor.dart` | `Transport`/`Link`, `ConnectRefused`, the in-process network (with a frame filter for tests), envelope framing and `Liveness` pings |
| `reconnector.dart` | `Reconnector` and `Backoff`: keeps a participant connected, resuming from its last `seq` |
| `mailbox.dart`, `clock.dart` | The one-at-a-time queue, `Clock` and `FakeClock` |
| `xoshiro_rng.dart` | The production `Rng` |
| `diagnostic_log.dart`, `report_bundle.dart` | `DiagnosticLog`, `Redactor`, `DiagnosticSink`; `ReportBundleBuilder` (see 04-session.md, Diagnostics) |

## Rules the host keeps

- **Store before broadcast.** `_commit` evolves a copy, appends, and only then replaces state and sends.
- **Identity comes from `hello`.** The `IdentityVerifier` decides who a link is and whether the agent is anonymous; later frames are authorized on that, never on `from`.
- **Entity ids never repeat after a reopen.** The id source restarts at the larger of one past the highest `e<N>` in the replayed state and the counter stored with the head snapshot.
- **RNG draws are never reused.** After every `decide`, a changed draw count is saved with `saveRngDrawCount`; every append carries it too. A reopen resumes at the larger of that and the state's own count.
- **A retried request never decides twice.** The host remembers `(agent, request id)` per answered request, including across a reopen (the stored event records its origin). Refused requests are not stored, so a retry after a reopen is decided again, to the same refusal.
- **GM identity is checked.** A verified identity flagged `isGm` is admitted only if it is the episode's GM; everything else must have an alias.

## Plugging in

- **Engine codec.** `EngineCodec` (in `protocol`) turns commands, events and state into JSON. Until row 6 supplies it, tests use `test/support/test_codec.dart`.
- **Consequence gate.** The host holds every event that is a `Consequence` (the engine's marker) until `confirmPending` or the episode's auto-confirm setting; rolls are never consequences, so they are never held. A review `edit` must return the same consequence type for the same entity, actor and visibility, or `confirmPending` throws and the batch stays pending.
- **What players receive.** `projectFor` shapes the copy of an event a player or the table gets: `overriddenFrom` is dropped and a multi-alias event is narrowed to the viewer's alias. The store and the GM keep the whole event. Add a case when a new event can address several aliases or carries GM-only detail.
- **Text log.** Each commit stores the engine `Narrator`'s lines as `gm`, `public`, `redacted` and `alias:<id>` variants.
- **Authorization.** `DefaultAuthorizer(playerMay: ...)` lists the commands players may send.
- **Diagnostics.** Pass `diagnostics: DiagnosticLog(...)` to `EpisodeHost.open` or `EpisodeParticipant`. To add a call point, call `diagnostics?.record(category, 'dotted.kind', {fields})` with facts about the machinery only (seqs, counts, reason codes). Never pass message text or notes; the `Redactor` hides the common field names (`text`, `notes`, `name`, `joinCode`, ...) and pseudonymises ids, but a new free-text field should be added to `Redactor.hiddenKeys`. In `backend`, `DiagnosticFileSink` persists the log and `writeReportBundle` saves a bundle to a folder.
- **Transports.** Implement `Transport`/`Link`; frames are strings. Cap what the transport buffers per frame at `maxFrameLength`; the codec refuses longer frames before parsing, but cannot stop a transport from buffering them. Throw `ConnectRefused` from `connect` when retrying cannot help (a wrong join code). The LAN transport is in `backend` (see below).
- **Liveness.** `host.listen(transport, liveness: Liveness(...))` and `EpisodeParticipant(liveness: ...)` ping every `interval` and close a link that has been silent for `timeout` (any frame counts). Off when null, as in most tests.
- **Reconnect.** `Reconnector(participant:, transport:, address:).run()` connects, waits on `participant.linkDone`, and connects again after a `Backoff` wait (500 ms doubling to 30 s; back to 500 ms after a link that was welcomed). Each new link sends `hello` with `lastSeq`, so the host replays the gap and pending requests are re-sent (deduplicated by request id). It stops on `stop()` (which also ends a pending connect or backoff wait), a readable `refused`, `ConnectRefused`, or a `FormatException` for the address. A welcomed link resets the backoff even if it drops at once. `LanClientTransport` times a connect out after 10 s.

## LAN transport (`backend`)

`packages/backend/lib/src/lan/` holds the demo's LAN transport (S-6: `dart:io` HTTP server and WebSockets, no package).

- **Joining.** `LanHostTransport.bind()` listens on every IPv4 interface at a free port with a new six-character join code; `joinInfo(host)` gives the `LanJoinInfo` (host, port, code) a player types or scans, as the address `ws://host:port/join?code=CODE`. That is all the LAN QR carries. `lanAddresses()` lists this machine's IPv4 addresses to show. A wrong path or code gets HTTP 404 or 403 before any link opens, which `LanClientTransport.connect` turns into `ConnectRefused`.
- **Frame cap.** Each socket is read through a `WebSocketFrameGuard` (`frame_guard.dart`), because `dart:io` limits each WebSocket frame (`maxPayloadLength`) but joins a message's continuation frames with no total limit. The guard reads frame headers only and destroys the socket as soon as one message passes `maxFrameBytes` (3 × `maxFrameLength`, the most UTF-8 bytes a legal frame can take), before the bytes are buffered. A text frame that arrives but is longer than `maxFrameLength` UTF-16 units is dropped and the link stays open. Both are logged as `lan.oversize`. Compression is off (no inflate on the receiving side).
- **Proxies.** The client connects directly (`findProxy` is `DIRECT`), whatever proxy the environment sets.


## Open

- Held consequence batches are in memory: closing or reopening the host loses them without a message. Whether they should survive a reopen is for R.
- The host stores text-log lines but never sends a `textlog` message (that message is for archived text from earlier engine majors).
- `projectFor` covers the events that can address several aliases today (`BroadcastDelivered`, `CheckRequired`, `CheckResolved`) and the three that carry `overriddenFrom`; a new event with either property needs a case.
- The host never decodes a stored snapshot: it replays the log. Snapshots for fast joins come later.
- Admission (invites, bans, locks, the anonymous alias map) lives in memory: a reopened host starts empty until the account layer repopulates it.
- Frames are sent one link at a time inside the commit, so a slow link delays the loop. Exception, the LAN transport: `_WebSocketLink.send` queues the frame in the socket and returns at once, so a slow LAN link does not delay the loop; the cost is memory instead, because nothing limits that queue ([09, LAN sends have no backpressure](../architecture/09-open-decisions.md#lan-backpressure)).
- `Welcome` carries no events; the host sends them in `events` frames right after it.
- A malformed `welcome` or `refused` drops the link (`hello.malformed`), so a `Reconnector` tries again after its backoff; a host that keeps sending a malformed refusal is retried at the 30 s cap, never reported as refused.
- `Backoff` has no jitter: every participant of a restarted host retries on the same schedule. Fine for a LAN table; worth adding before the relay.
- The LAN transport is tested over loopback only; the two- and three-machine runs are row 7. No end-to-end LAN test with a real `EpisodeHost` yet: the dependency rules (00-overview) keep the engine out of `backend`, tests included, so row 6 composes them in the app.
- The join code has about 30 bits and no wrong-attempt limit; each wrong code is logged as `lan.refused`.
- No participant-side narrator or store yet.
- Co-recipients stay hidden: `projectFor` narrows `BroadcastDelivered` to the viewer.
- `hidden` entries keep `seq` consecutive per recipient; an entry without exactly one of `event`, `redacted` and `hidden` is malformed and forces a resync; the RTDB relay stores events per audience, so row 15 must decide how a player reads a gapless sequence from it.

## Store health

`SembastEventStore.health(episodeId)` reports the commit marker, event and text-line counts, how many events recovery deleted when the file was opened, and the file size (pass `sizeOf:` to the constructor; the store itself does no file I/O). A non-zero discard count means the previous run ended in the middle of a batch. The saved report reads it.

## Kill test for the sembast store

`bash packages/backend/tool/kill_probe/run.sh [runs]` (from the repository root, Git Bash) compiles a writer and a checker, kills the writer with SIGKILL at random moments, and reopens the file after each kill. It fails if a batch the writer reported as committed is missing, the log has a gap, or text lines and head disagree with the events. It needs only Dart. It is run by hand, not by `check_all.sh`. Results so far: Linux, 25 kills (a throwaway script) and 12 kills (this script), 0 failures. Windows (R's PC, Git Bash, commit d59c5b7): 25 kills, 0 failures; `kill -9` reached the native process. These are process kills only: OS crash and power loss are not tested, and sembast calls no fsync [V-31]. The script stops with an error if the writer survives a kill.
