# 09. Open decisions and concerns

Everything here waits for R. Each open decision lists options, trade-offs and a recommendation. Nothing in the other chapters depends on the outcome beyond an interface.

Package versions below are the latest on pub.dev when this spec was written [V-18][V-4]; platform support for each candidate must be re-checked on its pub.dev page before adoption.

## 1. State management

How view models notify views. The engine and session already provide immutable state streams, so this choice is only about the UI layer.

| Option | What it is | For | Against |
|---|---|---|---|
| A. Flutter built-ins: `ChangeNotifier` / `ValueNotifier` + `ListenableBuilder`, constructor injection | The Flutter architecture guide's own approach [V-2][V-3] | No dependency; matches official docs R and D will read; the event-sourced core already does the hard part | DI and scoping are manual (one composition file) |
| B. `provider` | Thin layer over InheritedWidget, used in Flutter's own state-management tutorial [V-3] | Familiar; tidy DI and scoping | One dependency for little beyond A |
| C. `riverpod` 3.4.3 | Reactive caching and DI framework [V-4] | Strong DI, testable overrides, async helpers | Larger concept surface; its ecosystem includes a code generator (`riverpod_generator`) [V-4]; more to learn for maintainers |
| D. `bloc` 9.2.1 / `flutter_bloc` 9.1.1 | Event → state streams per feature [V-4] | Very explicit; good test tooling (`bloc_test`) | Duplicates the command/event model the engine already has; most boilerplate |

**Recommendation: A.** The engine and session already give a strict command → event → state flow. View models only need to project that into UI state and notify, which `ChangeNotifier` does with no dependency, and the official guide documents it. If DI wiring gets painful, adding B later is cheap and does not change view models.

## 2. Routing

| Option | For | Against |
|---|---|---|
| A. `Navigator` with `MaterialPageRoute` only | No dependency | Flutter docs: apps with deep-linking needs and web address-bar sync should use the Router [V-5]; we need both (join links, web) |
| B. `go_router` 18.1.0 (publisher flutter.dev) [V-5] | Declarative routes, deep links, web history; recommended in Flutter's navigation docs [V-5] | One dependency; route config is a central file to maintain |
| C. Raw `Router` API (own `RouterDelegate` / `RouteInformationParser`) | Full control, no dependency [V-5] | Most code to write and maintain |

**Recommendation: B.** Join links ("open this operation as this alias") and the web target make deep linking a requirement, and go_router is the option Flutter's docs point to [V-5]. Named routes are not recommended by Flutter [V-5].

## 3. Persistence

Local storage for: event logs, snapshots, cached packs, account cache, settings. Must work on every target including web, where `dart:io` files are unavailable [V-12]. The session sees only the `EventStore` interface ([04-session.md](04-session.md#interfaces-the-session-depends-on)).

| Option | For | Against |
|---|---|---|
| A. `sembast` 3.9.0 + `sembast_web` 2.4.6+1 (IndexedDB) [V-18] | Pure-Dart NoSQL document store; append-only JSON logs map directly onto it; no code generation | Querying is basic; large logs need care with snapshots (already designed in) |
| B. `drift` 2.35.2 (SQLite, has web/wasm backends) [V-18] | Relational queries, migrations, mature | Uses code generation (`drift_dev` with build_runner) [V-18], which CLAUDE.md §10 requires documenting; web setup more involved |
| C. `hive_ce` 2.22.0 [V-18] | Simple key-value boxes, fast | Typed adapters usually generated; less natural for ordered logs |
| D. Firebase SDK offline cache only | No extra package | `firebase_dart` persists query results, not pending writes, per the investigation [V-27][U]; ties offline play to Firebase |

**Recommendation: A**, behind `EventStore` and a small `KeyValueStore` for settings. The data is append-only JSON with lookups by operation and seq, which is what a document store does well, and it avoids code generation. If the account/library side later needs relational queries, B can be added for that data alone without touching the event store. The adopted backend design assumes a local outbox and pack cache ([06-accounts-backend.md](06-accounts-backend.md#offline-accounts-fixed-requirement)), which A fits; the store itself is still R's choice.

## 4. Networking and sync

The sync model is fixed by the authority decision (one ordered GM log; see [04-session.md](04-session.md#offline-and-sync-semantics)), so no CRDT or merge strategy is needed. What is open is **which transports to build, and in what order**. All implement the same `Transport` interface.

| Transport | Candidate | For | Against |
|---|---|---|---|
| In-process | none needed | Same-device play, tests | — |
| LAN | WebSocket over `dart:io` on the host + `web_socket_channel` 3.0.3 on clients [V-18]; discovery with `bonsoir` 7.1.5 (Zeroconf) [V-18] | No internet needed; companion phones at the table | Host must be native (no `dart:io` on web) [V-12]; discovery plugin platform coverage to verify |
| Backend relay: Realtime Database (**Fixed: adopted by R**) | `firebase_dart` / FlutterFire adapter | No server to run; listeners worked across instances at about 50 ms in the probe [V-21]; per-path rules | Rules still to prototype (probe 8.6) |
| P2P | `flutter_webrtc` 1.6.2+hotfix.4 (data channels) [V-18] | Direct links, no relay cost | Needs signaling plus STUN/TURN for NAT traversal [V-17]; most complex to debug |

The network-hosted relay is now fixed as Realtime Database. **Recommendation** for the rest: build in this order: in-process → LAN → RTDB relay → P2P. P2P comes last because it needs the most infrastructure and is the hardest for R and D to maintain.

## Proposed design choices needing approval

These are choices this spec makes that R has not ruled on.

| # | Proposal | Where |
|---|---|---|
| P1 | Extra packages: `content_core` (data), `backend` (Firebase adapters), `ui_kit` (shared widgets) | [00-overview.md](00-overview.md#repository-layout-proposed) |
| P2 | Pub workspace monorepo layout `packages/` + `apps/` | [00-overview.md](00-overview.md#repository-layout-proposed) |
| P3 | Rules packs as JSON files with a manifest | [02-rules-packs.md](02-rules-packs.md#pack-structure-proposed) |
| P4 | Data-only dice expressions and formulas (no scripting) | [01-engine.md](01-engine.md#dice-and-checks-vocabulary) |
| P5 | Engine-owned PRNG instead of `dart:math` `Random` | [01-engine.md](01-engine.md#rng) |
| P6 | Hand-written JSON codecs (no codegen) | [03-protocol.md](03-protocol.md#envelope-proposed) |
| P7 | Actors as single-threaded mailbox objects, not isolates | [04-session.md](04-session.md#coarse-actors-fixed-structure-proposed-shape) |
| P8 | Migrator works on frozen JSON schemas. (Partly ruled: archive-only logs are now R's ruling, below; the frozen-schema approach is still a proposal.) | [05-migrator.md](05-migrator.md) |
| P9 | Badge sign-in via a Dart Cloud Function minting a Firebase custom token | [06-accounts-backend.md](06-accounts-backend.md#badges-fixed-concept-proposed-mechanism) |
| P10 | Realtime Database model and rules (per-audience branches, write-once logs, fixed anonymous alias key), backend port with `FirebaseDartAdapter` / `FlutterFireAdapter` / `LanAdapter`, three Firebase environments | [06-accounts-backend.md](06-accounts-backend.md#realtime-database-model-proposed) |
| P11 | Deprecation record (`since`, `replacedBy`, `removeIn`, `note`) for engine schema and pack entries; warnings only within a major; `replacedBy` feeds the next migrator step | [01-engine.md](01-engine.md#deprecation-proposed-mechanism), [02-rules-packs.md](02-rules-packs.md#deprecation-in-packs) |
| P12 | Text log written during play by an engine event narrator, one variant per perspective, in the same durable write as the events, plus a head snapshot per batch; `textlog` protocol message; archive viewer and in-log placement; genesis `archives` list; new op id with seq restart; per-audience Realtime Database branches | [01-engine.md](01-engine.md#responsibilities), [04-session.md](04-session.md#the-operation-loop-gm-canonical-fixed), [05-migrator.md](05-migrator.md#archived-logs-fixed-ruled-by-r), [06-accounts-backend.md](06-accounts-backend.md#realtime-database-model-proposed) |
| P13 | Migration confirmation: separate warning screen; tick "cannot be recovered" and type the operation name | [05-migrator.md](05-migrator.md#gm-workflow) |
| P14 | Dart Cloud Function set (badge login, role claims, payment webhook, store receipts, push, pack publishing helper) and in-app inbox (`/users/$uid/inbox`) as the push substitute on Windows/Linux | [06-accounts-backend.md](06-accounts-backend.md#cloud-functions-dart-https-only-function-list-proposed) |

Ruled by R since the first draft: archived logs are frozen, not converted; a plain-text rendering is kept beside them for the in-game log and an archive viewer; the new log starts at `OperationMigrated`; the GM must explicitly confirm the unrecoverable loss.

## Open items for R

| # | Item | Context |
|---|---|---|
| W1 | **Disallow GM hosting on the web build entirely?** Not decided. | R noted a web GM loses control over engine version, pack choice and modifying their own games, which most GMs want. If disallowed, the web build is player-only (join, play, phone) and every hosting mode lives in native builds. If allowed, web hosting is limited to the relay and P2P. The session already exposes available hosting modes per platform, so either answer is a configuration of the app, not a structural change. No recommendation: this is a product call for R. |
| B1 | **Keep a Firestore database as a REST escape hatch?** | `firebase_dart` can read Firestore over REST with an ID token [V-21], but that needs a Firestore database alongside RTDB. Not decided. |
| B2 | **Unproven probe items.** | 8.1 queued SDK write surviving an app restart (design relies on its own outbox regardless), auth-required rules on real data, token expiry; 8.1b RTDB REST writes from a function with a service-account token; 8.1c native Windows RTDB via FlutterFire `firebase_database` 13.0.0; 8.3 real custom-token sign-in on Windows/Linux; 8.4 `getIdToken(true)` refresh and claim pickup; 8.5 anonymous upgrade via Identity Toolkit `accounts:update` keeping the uid; 8.6 RTDB rules prototype; 8.7 FlutterFire Firestore link error on Windows. Also untested: Cloud Storage through `firebase_dart`, long sessions, macOS/iOS/Android/web. |
| B3 | **RTDB writes that need admin rights.** | `firebase_admin_sdk` has no RTDB support [V-24]. Default: clients write under rules (GM writes members, moderators move library items). Alternatives: RTDB REST from a function (8.1b) or a Node function (R's approval). Unverified lead: `firebase_admin` 0.3.1+5, a pure-Dart admin port by the publisher of `firebase_dart` (appsup.be), may cover RTDB admin; not checked. Any use would need R's approval (CLAUDE.md §6). |
| B4 | **App Check on desktop.** | `firebase_app_check` lists Windows but official docs do not [V-26][U]; nothing for Linux or `firebase_dart`. |
| B5 | **Token storage on desktop.** | `firebase_dart` stores auth tokens at its setup path, plaintext unless encrypted [U]. Decide whether to encrypt. |
| B6 | **Calling Dart functions from desktop.** | HTTPS POST with a Bearer ID token and the callable envelope [U]; also confirm `firebase_admin_sdk` works inside the function runtime and where service-account keys are held. |

## Concerns raised

Each is raised once, per CLAUDE.md §2. R's answer stands.

1. **Firebase on desktop vs "all Flutter targets". Resolved by R.** FlutterFire Firestore/Auth are beta on macOS and Windows, Windows is development-only, and Linux is not listed [V-10]. R adopted `firebase_dart` on desktop (probed on Windows and Linux [V-21]), Realtime Database instead of Firestore, and HTTPS-only Dart Cloud Functions; Linux is required in v1. The Cloud Run gateway is dropped. Remaining unproven items are open items B2–B6 above.
2. **Web GM cannot host LAN. Ruled by R: accepted.** Browsers have no `dart:io` sockets [V-12]. R also set the web build's role: a lightweight client for people who have not installed the app yet, without full feature parity with native builds. See open item W1 above.
3. **Rulebook inconsistencies** (proficiency bonus, derived-stat operators, the top category glyph, disorder table layout, occult check attribute). Listed in [01-engine.md](01-engine.md#rulebook-gaps-found-while-writing-this). The engine supports all variants; the core pack needs R/D rulings before it is authored.
4. **Alias transfer approval.** R specified that moving an alias needs GM approval. Unspecified: the destination GM, the source GM, or both. Recommendation: destination GM approves; the source campaign is notified, and an alias in a running operation cannot move until that operation ends.
5. **Library verification workflow.** Who may verify items, and whether verification can be revoked, is not specified. Recommendation: an admin custom claim held by R and D only, revocable, with the verifier and date recorded on the item.
6. **Payments.** No provider, product or entitlement model is decided. The backend investigation sketched Stripe Checkout via an `onRequest` webhook setting a tier claim, but payment and store policy were not researched (probe 8.8). The spec reserves an `Entitlements` read model fed by claims.
7. **Physical dice.** Not requested. If tables want to roll real dice, `CheckResolved` can carry `source: entered` with GM-entered faces. Flagged only so the event shape leaves room; not proposed as a feature.
