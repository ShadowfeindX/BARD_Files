# 00. Overview

## Goals

1. Run *The B.A.R.D. Files* remotely, in person, or offline, with a **GM experience** (run the world, NPCs, checks) and a **player experience** (as immersive as a 2D screen allows).
2. Let the app adjudicate rules where it can, while the GM stays in charge of every call.
3. Keep game rules testable and reusable everywhere: main app, companion phone app, and any server.
4. Let R and D maintain and extend the system without Claude: small packages, plain data, few dependencies, no hidden magic.

## Fixed decisions

These come from R and are not reopened here. Items ruled on 2026-10-20 keep their review id (P, F, FS, B, W) so the record traces back; items that wait on D are marked **Pending D** and described in [09-open-decisions.md](09-open-decisions.md#pending-d).

| Area | Decision |
|---|---|
| Stack | Flutter / Dart only. |
| Targets | v1 (R, 2026-10-20): **Windows and Linux desktop**, plus the web player build; macOS and iOS are not in v1. Main app focuses on landscape medium/large screens. A companion phone app is built in parallel. The web build is a lightweight, **player-only** client for people who have not installed the app, without full feature parity; no GM hosting on web for now (W1, option A, ruled by R 2026-10-20). Revisiting W1 (web GM hosting, new-user onboarding) is Pending D: see [09-open-decisions.md](09-open-decisions.md#pending-d). |
| Structure | Hybrid: ECS-style pure-Dart game domain, coarse actors for the session/runtime layer, event-sourced core (command → events → state). |
| Repository | Pub workspace monorepo, `packages/` plus `apps/` (P2, fixed). Packages `engine`, `protocol_envelope`, `protocol`, `session`, `migrator`, plus `content_core`, `backend` and `ui_kit` (P1, fixed), shared by the main app and the companion app; the functions app depends only on `protocol_envelope` (F4). |
| Engine purity | The engine has no Flutter, Firebase or UI imports, and no wire-format concerns: the envelope and message types live in `protocol_envelope` (F4, option A), engine codecs in `protocol`. |
| Authority | No server authority and no anti-cheat. Every client runs its own engine. In an operation the GM's client is canonical: players send requests, the GM engine resolves them and broadcasts events. |
| Hosting | "Network-hosted" means the backend relays live play (Realtime Database) and keeps finished operations at rest (Firestore, FS1). P2P, LAN, in-person and offline play must all work. A signed-in account works offline from a local cache. |
| Rolls | The app adjudicates where possible. The GM decides when a roll is needed and which skill. Rolls are never gated or altered; the GM reviews consequence values (damage, sanity loss, conditions) and may edit them before they are broadcast (F2). Seeded, logged RNG: the engine's `Rng` interface, with the `xrandom` adapter in the GM's `session` (P5). The log stores resolved results, so history never changes. |
| Vocabulary vs values | The engine owns vocabulary (kinds of things and how they compute). Rules packs own values. The app shell never affects outcomes. Packs declare the engine API major they need. |
| Updates | Engine updates apply to operations automatically by default; pack updates apply manually by default. GMs get a toggle for each. |
| Cross-major | Migrator only. Each engine major knows only its own schema. A separate migrator transforms an operation's state and pack from N to N+1, run by the GM, who reviews the result. No frozen prior engine, no old web build. Old event logs are frozen, not converted, with a plain-text log kept beside them; the GM explicitly confirms the unrecoverable loss. |
| Accounts | Agent (player account) with many aliases; each alias locked to one campaign at a time (moving needs the destination GM's approval; the source campaign is notified; an alias in a running operation cannot move until it ends; concern 4). Anonymous accounts can join any session, have exactly one alias, cannot GM, host or create content. Badges are an optional scannable login. |
| Backend | Firebase first, with the console as the admin tool for D and auditors. Backend role only: accounts, session persistence/relay, rules pack distribution, info dissemination, payments. Adopted stack: `firebase_dart` client (FlutterFire only where needed), Realtime Database for **live play only** and Firestore for **data at rest** (FS1: archive, library, pack index, searchable account data), Cloud Storage for pack files, Hosting, HTTPS-only Dart Cloud Functions (experimental, accepted). No separate Cloud Run service is planned (the earlier gateway is dropped). Windows and Linux are the v1 desktop targets. See [06-accounts-backend.md](06-accounts-backend.md#stack-fixed-adopted-by-r). |
| Content | GMs create NPCs, items, skills, techniques. D publishes default content (cloud-hosted). The public library shows only verified items. Typst document templating comes later. |
| State management | `signals_flutter` 7.1.0 (publisher rodydavis.com), in the apps and `ui_kit` only; not the umbrella `signals`. Engine, protocol, session and migrator stay free of it ([V-29]). |
| Routing | `go_router` 18.1.1 with `app_links` 7.2.2 for desktop link delivery. Canonical link `bard://join/<op>?alias=<id>`; verified live on Linux and Windows ([V-30]). |
| Persistence | `sembast` 3.9.0 (`sembast_web` 2.4.6+1 for web player caches): one database file per operation, opened on demand, plus a small account/cache database. Commit-marker write protocol; no power-loss protection in v1 ([V-31]). |
| Randomness | Pub package `xrandom` 0.7.2, class `Xoshiro128pp` (never the `Xrandom`/`Drandom`/`Qrandom` aliases), pinned exactly, used in `session` behind the engine's `Rng` interface ([V-28]). See [01-engine.md](01-engine.md#rng-fixed). |
| Transports | Build order: in-process, LAN, RTDB relay, P2P (09-4). Their packages (`web_socket_channel`, `bonsoir`, `flutter_webrtc`) are not approved yet; each goes to R when its transport is scheduled. |
| Immersion | In-game phone messaging forwarded to the GM; per-perspective (player vs GM) panels. |

## Still open

- **Pending D** (R wants the creative director's approval first): occult check attribute (C5/G6); "cast magic" and the rest of the occult system (F3); exact pack shape and details (P3; the JSON + manifest format is fixed); the physical-dice feature (concern 7); revisiting W1. Pending D: see [09-open-decisions.md](09-open-decisions.md#pending-d).
- **P10c Firestore collections** are still to be drafted. The Realtime Database live-play tree and rules are ruled ([06-accounts-backend.md](06-accounts-backend.md#realtime-database-model-live-play)).
- **Probes:** all scheduled backend probes are done ([verification.md](verification.md#probe-status)); 8.1c, 8.7, Storage through `firebase_dart` and long sessions are not scheduled.

Every external choice stays behind an interface so it does not leak into the engine, protocol or migrator.

## System at a glance

```
            ┌─────────────────────────── GM device ───────────────────────────┐
 Player     │  UI (views + view models)                                        │
 device(s)  │        │ commands                ▲ state / read models           │
 ┌───────┐  │        ▼                         │                               │
 │  UI   │  │  session: OperationHost actor ── engine (decide / evolve) ── RNG  │
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
2. The GM's engine records `ActionRequested`. The GM chooses the skill and DC; the engine records `CheckRequired`, rolls with the operation's seeded RNG, and records `CheckResolved` with every die face.
3. Consequences (damage, sanity loss, conditions) become further events, held for GM review: the GM confirms them or edits values, and an edit is recorded on the event (F2). Rolls are never held.
4. The GM's session assigns each event a sequence number (rolls at once, consequences once confirmed), stores it, and broadcasts it, filtered to what each perspective may see.
5. Every client applies the same events to its own engine and gets the same state. Nobody re-rolls anything.

## Repository layout (fixed)

Uses a Dart pub workspace: one shared dependency resolution for every package [V-1].

```
/pubspec.yaml                 workspace root (lists members)
/packages/
  engine/                     pure Dart. Rules computation. No I/O.
  protocol_envelope/          pure Dart, SDK only. Envelope, message types, version negotiation.
  protocol/                   pure Dart. Engine command/event codecs; depends on protocol_envelope.
  session/                    pure Dart. Actors, operation loop, transport + store interfaces, Rng adapter (xrandom).
  migrator/                   pure Dart. Major N → N+1 transforms on serialized data.
  content_core/               D's default rules pack as data under assets/.
  backend/                    Flutter + Firebase adapters behind session/app interfaces.
  ui_kit/                     Shared widgets, theme, perspective panels.
/apps/
  bard/                       main Flutter app (GM + player, landscape medium/large)
  companion/                  phone Flutter app (player-first)
  functions/                  HTTPS-only Dart Cloud Functions (P14: badge login, roles, archiveOperation, push, pack publishing helper, payment/receipt placeholders)
/docs/                        developer guide, this spec
/reference/                   read-only copies of reference material (see CLAUDE.md §6)
```

R named `engine`, `protocol`, `session` and `migrator`. `content_core`, `backend` and `ui_kit` were approved as additional packages (P1) and `protocol_envelope` was added by ruling F4 (option A), so the engine carries no wire-format concerns and the functions app can speak the protocol without the engine. The pack contents of `content_core` follow the shape in [02-rules-packs.md](02-rules-packs.md); that shape is Provisional, pending D.

## Dependency rules

Arrows mean "may import" under `dependencies`. Anything not drawn is forbidden and should be enforced by a CI check on each `pubspec.yaml`. `dev_dependencies` (test-only) follow the same table except for the single exception listed below it.

```
apps/bard, apps/companion ──► session, protocol, engine, backend, ui_kit, content_core, signals_flutter, go_router, app_links
ui_kit                    ──► signals_flutter (Flutter widgets and theme only)
apps/functions            ──► protocol_envelope, firebase_functions, firebase_admin_sdk*   (never protocol, never the engine)
backend                   ──► session (interfaces), protocol, firebase_dart, hive (pinned), flutter_secure_storage, FlutterFire (only where needed, e.g. `cloud_firestore` on web); desktop Firestore through a hand-written REST client (FS2)
session                   ──► protocol, engine, xrandom (pinned; Rng adapter)
protocol                  ──► protocol_envelope, engine   (codecs for engine commands/events)
protocol_envelope         ──► (Dart SDK only)
engine                    ──► (Dart SDK only)
migrator                  ──► (Dart SDK only)     (works on serialized JSON, never imports engine)
content_core              ──► (none; data only)

dev_dependencies exception:
migrator (tests only)     ──► engine              (current major only; see 05-migrator.md)
```

\* `firebase_admin_sdk` 0.5.6 and `firebase_functions` 0.8.0 are **approved by R** (CLAUDE.md §6). `firebase_admin_sdk` covers Auth, Messaging, Storage, App Check, Firestore, Functions and Security Rules, but **not** Realtime Database [V-24]. `firebase_dart` is part of the stack R adopted. The other third-party packages above are approved by R at the versions in the Fixed decisions table and in the verification register ([V-28] to [V-36]); each version is re-verified on pub.dev just before it enters a pubspec (F5), and `xrandom`, `sembast` and `hive` are pinned exactly. `sembast` (with `sembast_web`) is used by the store implementations; which package holds them is set in [04-session.md](04-session.md) and [07-apps.md](07-apps.md).

`apps/functions` mints badge sign-ins, sets role claims, writes archived operations to Firestore (`archiveOperation`, FS3), sends push and helps publish packs; the payment webhook and store receipts are placeholders until payments are designed (concern 6, deferred). Functions reach RTDB through their own REST calls with the runtime default credential, one runtime service account per function group (FS3). It does not relay (Realtime Database is the relay for live play), validate packs or adjudicate anything: packs are validated by the engine on the publishing device before upload and again on every device that loads them ([02-rules-packs.md](02-rules-packs.md#loading-and-validation)).

Why these rules:

- **engine imports nothing** so it runs identically on every target, in tests, and on a server. No `dart:io`, because `dart:io` is unavailable on the web [V-12].
- **migrator imports nothing project-internal under `dependencies`** (tests may use the current engine; see the exception above) because a pub workspace has a single resolution and Dart does not allow two versions of the same package in one resolution [V-1]. It therefore cannot import engine N and engine N+1 together. It works on JSON with its own frozen schema descriptions instead (see [05-migrator.md](05-migrator.md)).
- **functions never import the engine, directly or transitively.** `apps/functions` depends only on `protocol_envelope` (F4, option A), which is SDK-only, so the engine cannot enter its dependency graph. The CI transitive check (see [08-testing.md](08-testing.md#continuous-integration-proposed)) holds: `engine` never resolves for `apps/functions`. Backend code therefore cannot adjudicate rules.
- **session never imports Flutter** so the same operation loop runs in the apps, a CLI, and tests. Platform-specific transports and stores are injected.

New pub dependencies in any package go to R first (CLAUDE.md §6). Not yet approved, and going to R when their feature is scheduled: `web_socket_channel`, `bonsoir`, `flutter_webrtc`, `barcode`, `mobile_scanner`, `flutter_zxing`.

## Layering inside the Flutter apps

Follows the Flutter architecture guide: a UI layer of views and view models, a data layer of repositories and services, and a domain layer where logic is complex [V-2]. For this project the domain layer *is* the `engine` and `session` packages.

```
View (widgets) ─► ViewModel ─► Repositories ─► Services
                      │             │              ├─ session (operation actors)
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
