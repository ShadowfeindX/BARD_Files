# 00. Overview

## Goals

1. Run *The B.A.R.D. Files* remotely, in person, or offline, with a **GM experience** (run the world, NPCs, checks) and a **player experience** (as immersive as a 2D screen allows).
2. Let the app adjudicate rules where it can, while the GM stays in charge of every call.
3. Keep game rules testable and reusable everywhere: main app, companion phone app, and any server.
4. Let R and D maintain and extend the system without Claude: small packages, plain data, few dependencies, no hidden magic.

## Platform and stack

The platform and stack chosen for the application; planned parts are labelled ([10 §5](10-waiting-on-d.md#5-workstream-rows-still-to-schedule)). Decisions and their reasons are in [decision-record.md](decision-record.md); items that wait on D are in [10-waiting-on-d.md](10-waiting-on-d.md).

| Area | Choice |
|---|---|
| Stack | Flutter / Dart only. |
| Targets | v1: **Windows and Linux desktop**, plus the web player build; macOS and iOS are not in v1. Main app focuses on landscape medium/large screens. A companion phone app is built in parallel. The web build is a lightweight, **player-only** client for people who have not installed the app, without full feature parity; no GM hosting on web for now. |
| Structure | Hybrid: ECS-style pure-Dart game domain, coarse actors for the session/runtime layer, event-sourced core (command → events → state). |
| Repository | Pub workspace monorepo, `packages/` plus `apps/`. Packages `engine`, `protocol_envelope`, `protocol`, `session`, `migrator`, plus `content_core`, `backend` and `ui_kit` and a theme-model package, proposed name `theme_core` (open: [T11](09-open-decisions.md#t11); not built), shared by the main app and the companion app; the functions app depends only on `protocol_envelope`. |
| Engine purity | The engine has no Flutter, Firebase or UI imports, and no wire-format concerns: the envelope and message types live in `protocol_envelope`, engine codecs in `protocol`. |
| Authority | No server authority and no anti-cheat. Every client runs its own engine. In an episode the GM's client is canonical: players send requests, the GM engine resolves them and broadcasts events. |
| Hosting | "Network-hosted" means the backend relays live play (Realtime Database) and keeps finished episodes at rest (Firestore) (planned; 10 §5 'RTDB live relay'). P2P, LAN, in-person and offline play must all work. A signed-in account works offline from a local cache (planned; 10 §5 'Offline account cache and session outbox'). |
| Rolls | The app adjudicates where possible. The GM decides when a roll is needed and which skill. Rolls are never gated or altered; the GM reviews consequence values (damage, sanity loss, conditions) and may edit them before they are broadcast. Seeded, logged RNG: the engine's `Rng` interface, with the `xrandom` adapter in the GM's `session`. The log stores resolved results, so history never changes. |
| Vocabulary vs values | The engine owns vocabulary (kinds of things and how they compute). Rules packs own values. The app shell never affects outcomes. Packs declare the engine API major they need. |
| Updates | Engine updates apply to episodes automatically by default; pack updates apply manually by default. GMs get a toggle for each. |
| Cross-major | Migrator only. Each engine major knows only its own schema. A separate migrator transforms an episode's state and pack from N to N+1, run by the GM, who reviews the result. No frozen prior engine, no old web build. Old event logs are frozen, not converted, with a plain-text log kept beside them; the GM explicitly confirms the unrecoverable loss. |
| Accounts | Agent (player account) with many aliases; each alias locked to one campaign at a time (moving needs the destination GM's approval; the source campaign is notified; an alias in a running episode cannot move until it ends). Anonymous accounts can join any episode, have exactly one alias, cannot GM, host or create content (campaign model planned; 10 §5 'Campaign-level members and rules'; the anonymous one-alias limit is built in the session layer). Badges are an optional scannable login (planned; not built, 10 §5). |
| Backend | Firebase first, with the console as the admin tool for D and auditors. Backend role only: accounts, session persistence/relay, rules pack distribution, info dissemination, payments. Stack: `firebase_dart` client (FlutterFire only where needed), Realtime Database for **live play only** and Firestore for **data at rest** (archive, library, pack index, searchable account data), Cloud Storage for pack files, Hosting, HTTPS-only Dart Cloud Functions (experimental). No separate Cloud Run service. See [06-accounts-backend.md](06-accounts-backend.md#stack). (planned; 10 §5 'Backend adapters and the sembast EventStore') |
| Content | GMs create NPCs, items, skills, techniques. D publishes default content (cloud-hosted). The public library shows only verified items (planned; 10 §5 'Library and pack index'). Typst document templating comes later (open: [T10](09-open-decisions.md#t10)). |
| State management | `signals_flutter` 7.1.0 (publisher rodydavis.com), in the apps and `ui_kit` only; not the umbrella `signals`. Engine, protocol, session and migrator stay free of it ([V-29]). |
| Routing | `go_router` 18.1.1 with `app_links` 7.2.2 for desktop link delivery. Canonical link `bard://join/<op>?alias=<id>`; verified live on Linux and Windows ([V-30]). |
| Persistence | `sembast` 3.9.0 (`sembast_web` 2.4.6+1 for web player caches): one database file per episode, opened on demand, plus a small account/cache database. Commit-marker write protocol; no power-loss protection in v1 ([V-31]). (planned; 10 §5 'Backend adapters and the sembast EventStore') |
| Randomness | Pub package `xrandom` 0.7.2, class `Xoshiro128pp` (never the `Xrandom`/`Drandom`/`Qrandom` aliases), pinned exactly, used in `session` behind the engine's `Rng` interface ([V-28]). See [01-engine.md](01-engine.md#rng). |
| Transports | Build order: in-process, LAN, RTDB relay, P2P. Their packages (`web_socket_channel`, `bonsoir`, `flutter_webrtc`) are not yet on the approved list (open: [S-6](09-open-decisions.md#s-6-transport-packages)); each goes to R when its transport is scheduled. |
| Immersion | In-game phone messaging forwarded to the GM; per-perspective (player vs GM) panels. |

## Still open

- **Waiting on D or R**: game-content and design items are in [10-waiting-on-d.md](10-waiting-on-d.md); platform and theme items are in [09-open-decisions.md](09-open-decisions.md).
- **Firestore collections** are drafted in [12-firestore-collections.md](12-firestore-collections.md) (Proposed; open: [S-7](09-open-decisions.md#s-7-firestore-collections)). The Realtime Database live-play model is in [06-accounts-backend.md](06-accounts-backend.md#realtime-database-model-live-play); its rules are checked by the emulator suite in `firebase/` [V-50].
- **Probes:** all scheduled backend probes are done ([verification.md](verification.md#probe-status)); 8.1c, 8.7, Storage through `firebase_dart` and long sessions are not scheduled.

Every external choice stays behind an interface so it does not leak into the engine, protocol or migrator.

## System at a glance

```
            ┌─────────────────────────── GM device ───────────────────────────┐
 Player     │  UI (views + view models)                                        │
 device(s)  │        │ commands                ▲ state / read models           │
 ┌───────┐  │        ▼                         │                               │
 │  UI   │  │  session: EpisodeHost actor ── engine (decide / evolve) ── RNG  │
 │   │   │  │        │ events (ordered, seq)   │                               │
 │session│◄─┼────────┤                         └── event store (local)         │
 │engine │  │        ▼                                                         │
 └───┬───┘  │  transport adapters (in-process │ LAN │ P2P │ backend relay)     │
     │      └────────┬────────────────────────────────────────────────────────┘
     │ requests      │ events (filtered per perspective)
     └───────────────┘
                     │ (network-hosted only)
              ┌──────▼───────┐
              │ Backend      │  Auth / RTDB (live) / Firestore (at rest) / Storage, Dart Functions
              │ relay+persist│  never runs game rules
              └──────────────┘
```

1. A player taps "pick the lock". The player's session sends a **request** (a command) to the GM.
2. The GM's engine records `ActionRequested`. The GM chooses the skill and DC; the engine records `CheckRequired`, rolls with the episode's seeded RNG, and records `CheckResolved` with every die face.
3. Consequences (damage, sanity loss, conditions) become further events, held for GM review: the GM confirms them or edits values, and an edit is recorded on the event. Rolls are never held.
4. The GM's session assigns each event a sequence number (rolls at once, consequences once confirmed), stores it, and broadcasts it, filtered to what each perspective may see.
5. Every client applies the same events to its own engine and gets the same state. Nobody re-rolls anything.

## Repository layout

Uses a Dart pub workspace: one shared dependency resolution for every package [V-1].

```
/pubspec.yaml                 workspace root (lists members)
/packages/
  engine/                     pure Dart. Rules computation. No I/O.
  protocol_envelope/          pure Dart, SDK only. Envelope, message types, version negotiation.
  protocol/                   pure Dart. Engine command/event codecs; depends on protocol_envelope.
  session/                    pure Dart. Actors, episode loop, transport + store interfaces, Rng adapter (xrandom).
  migrator/                   pure Dart. Major N → N+1 transforms on serialized data.
  content_core/               D's default rules pack as data under assets/. Pack today: a provisional copy of the example-core sample; D's pack is pending (10 §5 "Apply the target pack and engine values").
  backend/                    Flutter + Firebase adapters behind session/app interfaces (planned; scaffold only today, 10 §5).
  theme_core/                 pure Dart, SDK only. Theme model, codec, validator, resolver, colour math, built-in themes as JSON assets (name open: T11; not built).
  ui_kit/                     Shared widgets, theme widgets and controller, perspective panels.
/apps/
  bard/                       main Flutter app (GM + player, landscape medium/large)
  companion/                  phone Flutter app (player-first)
  functions/                  HTTPS-only Dart Cloud Functions (planned; scaffold only today, 10 §5): badge login, roles, archiveEpisode, push, pack publishing helper, payment/receipt placeholders
/docs/                        developer guide, this spec
```

`protocol_envelope` keeps wire-format concerns out of the engine and lets the functions app speak the protocol without the engine. A separate pure-Dart theme package (proposed name `theme_core`, open: [T11](09-open-decisions.md#t11)) lets the theme model grow after v1 without touching `ui_kit` ([07](07-apps.md#layering)); it is not built yet. The pack contents of `content_core` follow the shape in [02-rules-packs.md](02-rules-packs.md).

## Dependency rules

Arrows mean "may import" under `dependencies`. Anything not drawn is forbidden and should be enforced by a CI check on each `pubspec.yaml`. `dev_dependencies` (test-only) follow the same table except for the single exception listed below it, and the analysis and test tooling (`flutter_lints`, `test`, `flutter_test`), which every package may use. The repository tooling package `tool/` may use `yaml` only. The check is `tool/bin/check_dependency_rules.dart` ([developer guide](../developer-guide/setup.md#the-checks)).

```
apps/bard, apps/companion ──► session, protocol, engine, backend, ui_kit, content_core, theme_core, signals_flutter, go_router, app_links
ui_kit                    ──► signals_flutter, theme_core (Flutter widgets and theme widgets; the theme model is in theme_core)
apps/functions            ──► protocol_envelope, firebase_functions, firebase_admin_sdk*   (never protocol, never the engine)
backend                   ──► session (interfaces), protocol, firebase_dart, hive (pinned), flutter_secure_storage, sembast + sembast_web (pinned; the `EventStore`), FlutterFire (`firebase_core`, plus only where needed, e.g. `cloud_firestore` on web); desktop Firestore through a hand-written REST client
session                   ──► protocol, engine, xrandom (pinned; Rng adapter)
protocol                  ──► protocol_envelope, engine   (codecs for engine commands/events)
protocol_envelope         ──► (Dart SDK only)
engine                    ──► (Dart SDK only)
migrator                  ──► (Dart SDK only)     (works on serialized JSON, never imports engine)
content_core              ──► (none; data only)
theme_core                ──► (Dart SDK only)     (name open: T11; built-in themes as JSON assets)

dev_dependencies exception:
migrator (tests only)     ──► engine              (current major only; see 05-migrator.md)
```

\* `firebase_admin_sdk` 0.5.6 and `firebase_functions` 0.8.0 are planned for `apps/functions`; today it depends only on `protocol_envelope`. `firebase_admin_sdk` covers Auth, Messaging, Storage, App Check, Firestore, Functions and Security Rules, but **not** Realtime Database [V-24]. `firebase_dart` is part of the planned backend stack. The other third-party packages above are used or planned at the versions in the Platform and stack table and in the verification register ([V-28] to [V-36]); `firebase_dart`, `hive`, `flutter_secure_storage` and `sembast` are planned for `packages/backend` and are not in any pubspec yet; each version is re-verified on pub.dev just before it enters a pubspec, and `xrandom`, `sembast` and `hive` are pinned exactly. `sembast` (with `sembast_web`) is used by the store implementations; held by `backend` (the `EventStore`; see the table above).

`apps/functions` (planned; scaffold only today, 10 §5) mints badge sign-ins, sets role claims, writes archived episodes to Firestore (`archiveEpisode`), sends push and helps publish packs; the payment webhook and store receipts are placeholders until payments are designed. Functions reach RTDB through their own REST calls with the runtime default credential, one runtime service account per function group. It does not relay (Realtime Database is the relay for live play), validate packs or adjudicate anything: packs are validated by the engine on the publishing device before upload and again on every device that loads them ([02-rules-packs.md](02-rules-packs.md#loading-and-validation)).

Why these rules:

- **engine imports nothing** so it runs identically on every target, in tests, and on a server. No `dart:io`, because `dart:io` is unavailable on the web [V-12].
- **migrator imports nothing project-internal under `dependencies`** (tests may use the current engine; see the exception above) because a pub workspace has a single resolution and Dart does not allow two versions of the same package in one resolution [V-1]. It therefore cannot import engine N and engine N+1 together. It works on JSON with its own frozen schema descriptions instead (see [05-migrator.md](05-migrator.md)).
- **functions never import the engine, directly or transitively.** `apps/functions` depends only on `protocol_envelope`, which is SDK-only, so the engine cannot enter its dependency graph. The CI transitive check (see [08-testing.md](08-testing.md#continuous-integration)) holds: `engine` never resolves for `apps/functions`. Backend code therefore cannot adjudicate rules.
- **theme_core never imports Flutter** so the theme model, validator and colour math are testable in plain Dart and can serve later additions (theme distribution, per-campaign settings) without a widget layer. When it is built, the pub workspace members and the layer table in `tool/lib/dependency_rules.dart` are updated in the same change.
- **session never imports Flutter** so the same episode loop runs in the apps, a CLI, and tests. Platform-specific transports and stores are injected.

New pub dependencies in any package go to R first (CLAUDE.md §6). Not yet on the approved list, and going to R when their feature is scheduled: the transport packages (open: [S-6](09-open-decisions.md#s-6-transport-packages)) `web_socket_channel`, `bonsoir`, `flutter_webrtc`, and the badge packages (open: [S-8](09-open-decisions.md#s-8-badge-packages)) `barcode`, `mobile_scanner`, `flutter_zxing`.

## Layering inside the Flutter apps

Follows the Flutter architecture guide: a UI layer of views and view models, a data layer of repositories and services, and a domain layer where logic is complex [V-2]. For this project the domain layer *is* the `engine` and `session` packages.

```
View (widgets) ─► ViewModel ─► Repositories ─► Services
                      │             │              ├─ session (episode actors)
                      │             │              ├─ backend adapters (firebase_dart, FlutterFire, LAN)
                      │             │              └─ local stores
                      └── reads engine read-models (pure functions over state)
```

The app shell never computes outcomes. A view model may format a number the engine produced; it may not produce one.

## Cross-cutting principles

- **Immutability.** Engine state, components, commands and events are immutable values. New state is a new value.
- **Sealed families.** Commands and events are `sealed` class hierarchies so every `switch` over them is checked for exhaustiveness by the compiler [V-16]. Adding an event type is a deliberate, visible change.
- **Interfaces at every boundary.** Transport, event store, clock, RNG source, backend gateway and pack source are interfaces with in-memory test implementations.
- **Plain data for content.** Rules values are files that D can edit without touching Dart (CLAUDE.md §9).
- **One way to do each thing.** One event log format, one envelope, one pack format.
