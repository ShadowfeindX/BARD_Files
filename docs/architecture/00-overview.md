# 00. Overview

## Goals

1. Run *The B.A.R.D. Files* remotely, in person, or offline, with a **GM experience** (run the world, NPCs, checks) and a **player experience** (as immersive as a 2D screen allows).
2. Let the app adjudicate rules where it can, while the GM stays in charge of every call.
3. Keep game rules testable and reusable everywhere: main app, companion phone app, and any server.
4. Let R and D maintain and extend the system without Claude: small packages, plain data, few dependencies, no hidden magic.

## Fixed decisions

These come from R and are not reopened here.

| Area | Decision |
|---|---|
| Stack | Flutter / Dart only. |
| Targets | All Flutter targets. Main app focuses on landscape medium/large screens. A companion phone app is built in parallel. |
| Structure | Hybrid: ECS-style pure-Dart game domain, coarse actors for the session/runtime layer, event-sourced core (command → events → state). |
| Repository | Monorepo of packages (`engine`, `protocol`, `session`, `migrator`) shared by the main app, the companion app and any server. |
| Engine purity | The engine has no Flutter, Firebase or UI imports. |
| Authority | No server authority and no anti-cheat. Every client runs its own engine. In an operation the GM's client is canonical: players send requests, the GM engine resolves them and broadcasts events. |
| Hosting | "Network-hosted" means the backend relays and persists events. P2P, LAN, in-person and offline play must all work. A signed-in account works offline from a local cache. |
| Rolls | The app adjudicates where possible. The GM decides when a roll is needed and which skill, and can override any result. Seeded, logged RNG lives in the GM engine. The log stores resolved results, so history never changes. |
| Vocabulary vs values | The engine owns vocabulary (kinds of things and how they compute). Rules packs own values. The app shell never affects outcomes. Packs declare the engine API major they need. |
| Updates | Engine updates apply to operations automatically by default; pack updates apply manually by default. GMs get a toggle for each. |
| Cross-major | Migrator only. Each engine major knows only its own schema. A separate migrator transforms an operation's state and pack from N to N+1, run by the GM, who reviews the result. No frozen prior engine, no old web build. |
| Accounts | Agent (player account) with many aliases; each alias locked to one campaign at a time (moving needs GM approval). Anonymous accounts can join any session, have exactly one alias, cannot GM, host or create content. Badges are an optional scannable login. |
| Backend | Firebase first (Auth, Firestore, Hosting). Backend role only: accounts, session persistence/relay, rules pack distribution, info dissemination, payments. Dart server code targets Cloud Run. |
| Content | GMs create NPCs, items, skills, techniques. D publishes default content (cloud-hosted). The public library shows only verified items. Typst document templating comes later. |
| Immersion | In-game phone messaging forwarded to the GM; per-perspective (player vs GM) panels. |

## Still open (R decides)

State management, routing, persistence, networking/sync. See [09-open-decisions.md](09-open-decisions.md). This spec keeps every one of them behind an interface so the choice does not leak into the engine, protocol or migrator.

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
              │ Backend      │  Firebase Auth / Firestore / Hosting, Cloud Run (Dart)
              │ relay+persist│  never runs game rules
              └──────────────┘
```

1. A player taps "pick the lock". The player's session sends a **request** (a command) to the GM.
2. The GM's engine records `ActionRequested`. The GM chooses the skill and DC; the engine records `CheckRequired`, rolls with the operation's seeded RNG, and records `CheckResolved` with every die face.
3. The GM may override (`ResultOverridden`). Consequences become further events.
4. The GM's session assigns each event a sequence number, stores it, and broadcasts it, filtered to what each perspective may see.
5. Every client applies the same events to its own engine and gets the same state. Nobody re-rolls anything.

## Repository layout (Proposed)

Uses a Dart pub workspace: one shared dependency resolution for every package [V-1].

```
/pubspec.yaml                 workspace root (lists members)
/packages/
  engine/                     pure Dart. Rules computation. No I/O.
  protocol/                   pure Dart. Wire messages and codecs.
  session/                    pure Dart. Actors, operation loop, transport + store interfaces.
  migrator/                   pure Dart. Major N → N+1 transforms on serialized data.
  content_core/               Proposed. D's default rules pack as data under assets/.
  backend/                    Proposed. Flutter + Firebase adapters behind session/app interfaces.
  ui_kit/                     Proposed. Shared widgets, theme, perspective panels.
/apps/
  bard/                       main Flutter app (GM + player, landscape medium/large)
  companion/                  phone Flutter app (player-first)
  server/                     Dart server for Cloud Run (relay, badges, pack publishing)
/docs/                        developer guide, this spec
/reference/                   read-only copies of reference material (see CLAUDE.md §6)
```

The four packages R named are `engine`, `protocol`, `session`, `migrator`. `content_core`, `backend` and `ui_kit` are **Proposed** additions; the reasons are in their chapters and they are listed for approval in [09-open-decisions.md](09-open-decisions.md#proposed-design-choices-needing-approval).

## Dependency rules

Arrows mean "may import". Anything not drawn is forbidden and should be enforced by a CI check on each `pubspec.yaml`.

```
apps/bard, apps/companion ──► session, protocol, engine, backend, ui_kit, content_core
apps/server               ──► protocol            (relay never runs the engine)
backend                   ──► session (interfaces), protocol, Firebase plugins
session                   ──► protocol, engine
protocol                  ──► engine              (codecs for engine commands/events)
engine                    ──► (Dart SDK only)
migrator                  ──► (Dart SDK only)     (works on serialized JSON, never imports engine)
content_core              ──► (none; data only)
```

Why these rules:

- **engine imports nothing** so it runs identically on every target, in tests, and on a server. No `dart:io`, because `dart:io` is unavailable on the web [V-12].
- **migrator imports nothing project-internal** because a pub workspace has a single resolution and Dart does not allow two versions of the same package in one resolution [V-1]. It therefore cannot import engine N and engine N+1 together. It works on JSON with its own frozen schema descriptions instead (see [05-migrator.md](05-migrator.md)).
- **server imports only protocol** so the backend can relay and persist but structurally cannot adjudicate rules.
- **session never imports Flutter** so the same operation loop runs in the apps, a CLI, and tests. Platform-specific transports and stores are injected.

New pub dependencies in any package go to R first (CLAUDE.md §6). This spec names candidate packages only inside the open decisions.

## Layering inside the Flutter apps

Follows the Flutter architecture guide: a UI layer of views and view models, a data layer of repositories and services, and a domain layer where logic is complex [V-2]. For this project the domain layer *is* the `engine` and `session` packages.

```
View (widgets) ─► ViewModel ─► Repositories ─► Services
                      │             │              ├─ session (operation actors)
                      │             │              ├─ backend adapters (Firebase, Cloud Run)
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
