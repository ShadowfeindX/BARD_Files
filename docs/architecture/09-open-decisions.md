# 09. Open decisions

This chapter lists what is still open: items waiting on D, items waiting on R, open spec proposals, items held for a probe, deferred concerns, known issues and unproven claims. Decided items are not listed here; each chapter states its rulings as design only; ids, dates and reasons are in the record. The record of rulings (id, date, rationale) is [decision-record.md](decision-record.md).

D's open game-content and design questions, with their options and defaults, are in [10-waiting-on-d.md](10-waiting-on-d.md); R's open items from the same meetings are there too.

## Pending D

Still waiting on D and on R for the game-content and design items: see [10-waiting-on-d.md](10-waiting-on-d.md). The rows below are the platform and theme items.

| Item | What is undecided | Already fixed |
|---|---|---|
| DEC-41 map geometry (owner D; next R and D meeting) | Whether maps get any geometry rules: cover, terrain, line of sight, facing, areas. The rulebook has none. Numbered in the project library's design review (`design/synthesis-government-terminal.md`). | Until D rules, a map is style only and carries no rule effect (design, Proposed). |

## Open for R (themes)

Proposed in [07](07-apps.md#themes-and-player-appearance-settings), not ruled. These are what is left after T1, T7, T8, T9, T12, T14, T15 and T16; T5 and the T7 (e) labels were settled by D on 2026-11-05 (T13). Nothing built depends on them.

| Item | What is undecided | Proposed | Owner |
|---|---|---|---|
| <a id="t2"></a>T2 sync | Whether cross-client sync of the setting and custom themes is wanted at all in v1; whether "only for the player client" excludes the Handler console. | The Handler console keeps System (the player-client setting does not reach it). Local storage per client plus export and import in v1; optional sync later. If sync is added: owner-only `appearance/{uid}` (deferred in [12](12-firestore-collections.md#collections-at-a-glance)), never `agents/{uid}`, whose `keys().hasOnly` whitelist stays; the variant as a neutral rendering label with no health framing, because a synced colour-blind variant sits outside 11's real-personal-data list (alternatives then: variant local-only, or amend 11). | R |
| <a id="t3"></a>T3 custom-theme editor | The custom-theme editor: create by Duplicate or Derive, edit every token, live preview, advisories, and the reset safeguards (fallback chrome, timed revert, Reset to System). Outside the demo's scope; to come back to later (R, 2026-11-07). | Safeguards ruled 2026-11-05 (T12); the rest of T3 ruled 2026-11-07 (T15). Still Proposed: the editor as described in [07 Custom themes](07-apps.md#custom-themes-proposed-open-t3). | R |
| <a id="t4"></a>T4 effect token values | The values of the four new effect tokens `highlight`, `hostileTakeover`, `onHostileTakeover` and `sceneTint`; where the photosensitivity setting lives. | Names, the outdated-theme fill with its notice and **Add missing colours**, the variant reading, and the effect-safety pairs and minimums (mandatory for built-in themes only, advisories for custom themes) ruled 2026-11-05 and 2026-11-07 (T12, T14, T16). Still Proposed: the placeholder values (`supervisor`, `desk`, `anomaly`, `anomaly`) until their pairs are computed by the study's method and reported here; where the photosensitivity setting lives. | R |
| <a id="t6"></a>T6 document tokens and document mode | New document token names and values; document mode. | Token names and values ruled 2026-11-05 (T12; `paperStamp` is `#7E2A20`). Still Proposed: a Document mode toggle on every document view (per view plus a remembered preference) showing a fixed, non-themeable standard paper set, also used for print and export. | R |
| <a id="t10"></a>T10 document renderer | The pipeline that renders documents (typst or another solution; no new dependency or tool without R's approval, CLAUDE.md §6); the print default. Related ideas: the synthesis "Forms and filing" section (print and export), cited by name. | Not chosen. Print and export use the standard paper set; DEC-29's black on white is the alternative print default. | R |

## Open spec items

Proposals written into the chapters as structured designs, not yet ruled. Each has a stable id; the chapter that describes the proposal links here. Nothing built depends on them. Owner is the one who rules.

### O-05-1 Notice after migration

- **Undecided:** the notice players see in the log after a migration, saying that history before it is archived text.
- **Options:** one proposal: players do nothing and see the notice in the log.
- **Owner:** R. **Described in:** [05](05-migrator.md#gm-workflow).

### O-08-1 Pack-validation job

- **Undecided:** whether the example pack gets its own CI job. CI is built ([08](08-testing.md#continuous-integration)); pack validation currently runs inside the engine's tests (the pack loader loads the example pack), and there is no separate `content_core` validation step.
- **Options:** keep validation in the engine tests; or add a job that loads and validates every pack folder in `content_core`.
- **Owner:** R. **Described in:** [08](08-testing.md#continuous-integration).

### 06-O1 Firestore REST client token handling

- **Undecided:** the REST client's handling of a stale token and of index or claim errors. Calling `getIdToken()` on every request is decided and is not open.
- **Options:** proposed: never cache the token string; on 401 retry once with `getIdToken(true)`; surface `FAILED_PRECONDITION` as a missing-index error; force `getIdToken(true)` after a role change.
- **Owner:** R. **Described in:** [06](06-accounts-backend.md#firestore).

### 06-O2 Anonymous-to-full account upgrade

- **Undecided:** the upgrade path, and whether hosting requires a verified email (the upgraded account has `email_verified: false`).
- **Options:** proposed path: `updateEmail` then `updatePassword` on the signed-in `firebase_dart` user (keeps the uid), then `getIdToken(true)`; the Identity Toolkit `accounts:update` route is not used. The verified-email requirement is undecided.
- **Owner:** R. **Described in:** [06](06-accounts-backend.md#account-model).

### 06-O3 Claim pickup after a role change

- **Undecided:** how a client picks up a changed claim.
- **Options:** proposed: the roles function writes an inbox notice to `/inbox/$uid`; the client calls `getIdToken(true)` and reloads `Entitlements`. Untested whether a client without the notice picks the claim up when its token expires.
- **Owner:** R. **Described in:** [06](06-accounts-backend.md#roles).

### S-2 `SendPhoneMessage` names and fields

- **Undecided:** the command and field names of `SendPhoneMessage(from, to, text)`. The behaviour (party rules, 1 to 2,000 UTF-16 units) is design.
- **Options:** names and fields as proposed in the chapter.
- **Owner:** R (built; names open, see 01 Planned code changes, 'Built; names open'). **Described in:** [04](04-session.md#in-game-phone).

### S-3 Perspective-panel feature areas

- **Undecided:** the grouping of feature areas (Episode console, Dossier, World, Phone, Library, Filing); the content of each is to be set by R.
- **Options:** the grouping as proposed in the chapter.
- **Owner:** R. **Described in:** [07](07-apps.md#perspective-panels).

### S-6 Transport packages

- **Undecided:** the packages for the LAN and P2P transports: `web_socket_channel`, `bonsoir`, `flutter_webrtc` (CLAUDE.md section 12). Not approved.
- **Options:** none beyond these candidates; each goes to R with its purpose and alternatives when its transport is scheduled (build order: in-process, LAN, Realtime Database relay, P2P).
- **Owner:** R. **Described in:** [04](04-session.md#play-modes), [00](00-overview.md#platform-and-stack).

### S-8 Badge packages

- **Undecided:** the packages for badge printing and scanning: printing (candidate `barcode`), phone scanning (`mobile_scanner`), desktop scanning (`flutter_zxing`, Windows and Linux beta, or USB 2D keyboard-wedge scanners). None is on the approved list (CLAUDE.md section 6).
- **Options:** the candidates above; each goes to R with its purpose and alternatives when badges are scheduled.
- **Owner:** R. **Described in:** [06](06-accounts-backend.md#badges), [00](00-overview.md#dependency-rules).

### S-9 Gateable shell capabilities

- **Undecided:** which shell capabilities the Handler may gate. The library synthesis (section 12.7) proposes that theme, texture, motion and text-size settings are never gateable and that a lock card uses no flashing or motion beyond the standard window transition; the rest of capability gating is undecided (see DEC-34 and GAP-33 below).
- **Options:** one proposal, as written in the synthesis; appearance settings are not gateable.
- **Owner:** R. **Described in:** [07](07-apps.md#layering).

### S-10 Duplicate and gap detection between the host and the backend copy

- **Undecided:** the rule that detects whether the backend log holds events the GM device lacks, or the reverse, before the device resumes.
- **Options:** compare the last `seq` and the hash of the last event on each side (the proposal in the chapter); other rules are not yet considered.
- **Owner:** R. **Described in:** [04](04-session.md#offline-and-sync-semantics).

### API-1 Engine and pack API shapes

- **Undecided:** the names, fields and file shapes of the proposals marked "Proposed, open: API-1" in [01](01-engine.md) and [02](02-rules-packs.md): the engine's public API surface, the proposed pack-file fields and keys, the rounding fields, the `assistance`, `sanity_events`, `disorders`, `combat` and creation-profile shapes, the new commands and events, the library provenance field, the JSON form of the implemented `condition` node (`{"type":"compare","op":<lt|le|eq|ne|ge|gt>,"left":<formula>,"right":<formula>}`, six operators, no combinators),  whether a command-line validator exists ([02](02-rules-packs.md)) and the `packages/engine/schema/` documentation folder ([01](01-engine.md)).
- **Options:** one proposal per item, as written in the chapters. The behaviour is design; only names and shapes are open.
- **Owner:** R, at implementation. **Described in:** [01](01-engine.md), [02](02-rules-packs.md).

### DEC-07 Intrusion cues

- **Undecided:** whether and how intrusion cues happen (id from the project library's design review). The theme chapter only says which colours such effects may use (T4).
- **Options:** none written.
- **Owner:** R and D. **Described in:** [07](07-apps.md#effect-and-highlight-tokens).

### DEC-34 and GAP-33 Capability lock cards

- **Undecided:** which capability-lock-card effects exist (library synthesis section 12, revision 4).
- **Options:** none written.
- **Owner:** R. **Described in:** [07](07-apps.md#effect-and-highlight-tokens).

## Known issues and follow-ups

Not decisions; work still owed.

- **No web target.** `apps/bard` has `linux/` and `windows/` folders but no `web/`, so the player-only web build in the v1 platforms does not exist yet.
- **No Chrome widget tests.** CI runs the `engine` and `session` tests on Node.js as well as the VM. Nothing runs on Chrome, so `ui_kit` and `apps/bard` widget tests are unproven on the web.
- **`check_all.sh` fails in a checkout with untracked Dart files.** Its `dart format .` step covers the whole folder, including untracked ones such as local probes. A clean clone passes on its first run (checked on Windows, 2026-11-04).
- <a id="ui-style"></a>**UI style review.** The dossier look is not implemented and the UI style is in review, pending D's feedback (CLAUDE.md §12). `BardTheme` is a placeholder until then ([ui-kit notes](../ui-kit.md)).
- <a id="redactor-salt"></a>**High: must fix before beta or any real-user data. Diagnostic-log pseudonyms depend on a guessable salt, and report bundles carry plain ids.** `Redactor` (`packages/session/lib/src/diagnostic_log.dart`, added by the diagnostic-log PR) turns `agentId`, `aliasId`, `requestId`, `entityId` and `from` values into `agent-3fa9c1d2`-style pseudonyms: a 32-bit FNV-1a hash of `salt|id`. The salt is never written to a bundle, so with a secure random salt the ids cannot be tested against guesses. Three weaknesses remain:
  1. The salt comes from `Random.secure()`. Where that throws (seen on the Node.js test runtime) it falls back to a time-seeded `Random`, so the salt is guessable, and a 32-bit non-cryptographic hash over short or known ids can then be brute-forced to name agents and aliases.
  2. The hash multiplies past 2^53, which loses precision on JS, so web and native may give different pseudonyms for one id.
  3. `game-log.jsonl` and `text-log.jsonl` carry plain agent, request and alias ids (the text log as `alias:<id>` keys), whatever the redactor does. Numeric id values are also not pseudonymised.

  Fix before beta: a keyed hash from an approved crypto source (a new dependency goes to R first), fail closed (hide the id) when no secure random is available, the same result on web and native, and a ruling on whether bundles may ever carry real ids. Proposed for the demo: the risk is acceptable because testers are known and the data is placeholder; this is not yet ruled by R. **Owner:** R. **Described in:** [04](04-session.md#diagnostics) (the link resolves once the diagnostic-log PR is merged).
- <a id="lan-join-code"></a>**High: must fix before any internet-facing hosting. The LAN join code is short and can be guessed without limit.** `newJoinCode` (`packages/backend/lib/src/lan/lan_transport.dart`, added by PR #37) makes 6 characters from a 31-character alphabet: 31^6, about 8.9 × 10^8 codes (about 30 bits). `LanHostTransport._check` compares the `code` query parameter with a plain `!=` and answers every wrong guess with HTTP 403 at once, with no count, delay or lockout; each refusal is only logged as `lan.refused`. On a LAN table this is acceptable, since a guesser has to be on the same network during the session. On a reachable address, a script doing a few thousand guesses a second finds the code within days, and sooner with many connections in parallel. The code is also the only check before a link opens: `hello` identity checks follow, but an open link already reaches the host loop.
  Fix (proposed, not yet ruled by R): a longer code (at least 10 characters, about 50 bits) or a per-episode secret behind the QR, a limit on wrong attempts per remote address and per host (back off, then refuse for the rest of the session, logged), and a constant-time compare. **Owner:** R. **Found in:** PR #37, `LanHostTransport._check` and `newJoinCode`.
- <a id="lan-connection-cap"></a>**High: must fix before any internet-facing hosting. The LAN host does not limit unauthenticated connections.** `LanHostTransport.bind` (`packages/backend/lib/src/lan/lan_transport.dart`, PR #37) accepts every TCP connection through `HttpServer.listenOn`, with no cap on how many are open at once, from one address or in total. Before the join code is checked, each connection may hold up to 16 KiB of request headers (`WebSocketFrameGuard.maxHeaderBytes`, `frame_guard.dart`). There is no header deadline of our own: a client that sends its headers a byte at a time keeps the connection until `dart:io`'s idle sweep closes it (the server's default 120 s idle timeout, so about 2 to 4 minutes), and it can simply open another. After a successful upgrade, a link that never sends `hello` stays open for good unless the host turned `Liveness` on. Enough such connections exhaust file handles or memory and lock out real players. Low risk on a LAN; on a reachable address it is an easy denial of service.
  Fix (proposed, not yet ruled by R): cap open connections in total and per remote address (refuse with 503 past the cap), set a short header deadline and `HttpServer.idleTimeout`, and close a link that has not sent `hello` within a few seconds (or always run host `Liveness`). **Owner:** R. **Found in:** PR #37, `LanHostTransport.bind` and `LanHostTransport._onRequest`.
- <a id="lan-backpressure"></a>**Medium: LAN sends have no backpressure.** `_WebSocketLink.send` (`packages/backend/lib/src/lan/lan_transport.dart`, PR #37) calls `WebSocket.add`, which queues the frame in the socket's sink and returns at once. A joined player whose machine reads slowly is not dropped while it still answers pings, and a hostile one can keep sending its own pings (any frame counts as alive) while never reading; every broadcast to such a link piles up in the host's memory, up to `maxFrameLength` per frame. The loop itself is not slowed, because `send` returns before the bytes leave; the cost is memory. Low risk at a LAN table of a few players; it grows with episode length and player count, and matters for any hosting beyond the LAN.
  Fix (proposed, not yet ruled by R): give each link an outbound queue with a byte limit (count queued UTF-8 bytes, release them on `flush`), and close a link that passes it; the player reconnects and resyncs from `lastSeq`, so nothing is lost. **Owner:** R. **Found in:** PR #37, `_WebSocketLink.send`.
- <a id="lan-backoff-jitter"></a>**Low: reconnect backoff has no jitter.** `Backoff.delayFor` (`packages/session/lib/src/reconnector.dart`, PR #37) waits exactly 500 ms, then 1 s, 2 s and so on up to 30 s. When a host restarts, every participant retries on the same schedule, so they all reconnect, `hello` and resync in the same instant. At a LAN table of a few players this is harmless; on the relay or with many players it turns a restart into load spikes. `Reconnector` also resets the backoff after any welcomed link, so a host that welcomes and then drops every link is retried every 500 ms.
  Fix (proposed, not yet ruled by R): add random jitter to each wait (for example "full jitter", a random wait between zero and the computed delay, with an injected `Random` so tests stay deterministic), and reset the backoff only after a link has stayed up for a minimum time. **Owner:** R. **Found in:** PR #37, `Backoff.delayFor` and `Reconnector.run`.
- **Session gaps.** `docs/developer-guide/session.md` lists the known gaps in the session layer.

## Held

### S-7 Firestore collections

- **Held:** the Firestore collection draft (names, document shapes, rules and indexes), awaiting R.
- **State:** drafted in [12-firestore-collections.md](12-firestore-collections.md) (Proposed). RTDB rules are run in the Emulator Suite (200 of 200 [V-54], [V-56]). Firestore rules and indexes are not run.
- **Owner:** R. **Described in:** [06](06-accounts-backend.md#firestore), [12](12-firestore-collections.md).

## Deferred

- **Concern 6, payments.** No provider, product or entitlement model is decided. The `Entitlements` read model and placeholder webhook/receipt functions stay; probe 8.8 (provider and app-store policy) runs when R wants monetization designed, likely with D.

## Still unproven

- FS2 on Windows for natural expiry, plus revoked sessions, disabled users, password change and refresh-token failure (Linux natural expiry, composite indexes and claim rules: done [V-43][V-45]).
- FS3: the RTDB role from a deployed function running as its dedicated service account (tested by impersonation only) [V-46].
- 8.4 claim pickup on Windows (Linux done [V-42]).
- Storage: rules and client behaviour of Cloud Storage for Firebase (rules pack files) are not yet probed.
- RTDB rules on a deployed database with real signed tokens, and custom claims in RTDB rules (emulator only so far [V-38]).
- Opening an existing plaintext `firebase_auth` box with the cipher (the B5 migration step) [V-34][V-44].
- **VER-14 (themes, T1; defined in the project library's design review, recorded here as the repo's entry):** the built-in theme variants (the 12 sets in the library's `design/colorblind-palettes.md`), and the confirm, Warning and Locked colours are tested with real colour-blind players (at least protan, deutan and tritan viewers and one low-vision viewer) on the target displays. Testers to be chosen by R and D; values are revised if the test disagrees with the simulation. Proposed extension, not in the library's entry: include the `windowEdge`, effect and document colours once their values are set (T4, T6, T11).
- Invite links (the campaign form, Proposed) on Linux, Android and web: R (2026-11-04) saw the link work on the local Windows app only; web invites have no spec yet.
- Deep links on Wayland, Flatpak, Snap and packaged builds [V-30]. macOS and iOS are not in v1 (R, 2026-10-20), so their checks are dropped.
