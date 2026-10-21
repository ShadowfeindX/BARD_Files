# 07. Applications

## The three apps

| App | Platforms (Fixed scope) | Who | Role |
|---|---|---|---|
| `apps/bard` | v1: Windows and Linux desktop, plus the player-only web build; designed for landscape medium/large screens | GM and players | Full GM experience and full player experience on native builds. The web build is player-only (W1, see below) |
| `apps/companion` | phones (built in parallel) | players first | Character sheet, checks, in-game phone, notifications; joins operations the main app hosts |
| `apps/functions` | Firebase, HTTPS-only Dart Cloud Functions (experimental) | none directly | Badge login, role claims, payment webhook, store receipt validation, push, pack publishing helper (P14). Depends only on `protocol_envelope` (F4), never on the engine. No relay: Realtime Database is the relay |

Both Flutter apps use the same `session`, `engine` and `protocol` packages, so a companion phone and a tablet are equal participants in an operation. The companion app is a different **UI**, not a different client.

## Layering in each Flutter app

Following the Flutter architecture guide [V-2]:

```
lib/
  ui/
    <feature>/
      <feature>_view.dart          widgets only; no logic beyond show/hide, layout, animation
      <feature>_view_model.dart    UI state + commands (user intents) for that view
  data/
    repositories/                  sources of truth exposed to view models
    services/                      wrappers over session, backend gateway, local store, platform
  app/
    composition.dart               builds services/repositories and injects them (one place)
    routes.dart                    routing (go_router, 09-2)
  main.dart
```

- View models talk to repositories; repositories wrap services. The `session` package is used through a service, so view models never see actors or transports.
- View models expose **commands** (Flutter guide terminology for user-intent callbacks [V-2]). A command such as `requestLockpick()` turns into an engine command sent through the session. It never computes an outcome.
- **State management (09-1, Fixed; ruled by R 2026-10-20):** Dart Signals, through `signals_flutter` 7.1.0 (publisher rodydavis.com; Flutter bindings over `signals_core`) in `apps/` and `ui_kit` [V-29]. The umbrella `signals` package is not used; the engine stays SDK-only. View models expose signals, and views read them.
- **Routing (09-2, Fixed):** `go_router` 18.1.1 [V-30], with `app_links` 7.2.2 as the desktop link companion that delivers links to the router. The canonical join link is `bard://join/<op>?alias=<id>`, which every target can register; https links come later where supported. Verified live on Linux and Windows [V-30]. Android https links, when added, need `assetlinks.json`.
- **Persistence (09-3, Fixed):** sembast (+ `sembast_web` for web player caches) behind the session's `EventStore`, see [04-session.md](04-session.md#interfaces-the-session-depends-on).
- Package versions are re-verified on pub.dev before each enters a pubspec (F5).

## Perspective panels (Fixed feature)

The main app shows per-perspective panels: what the GM sees and what players see. Each panel binds to one perspective stream from the session ([04-session.md](04-session.md#perspectives)). A GM on a large screen can keep the GM panel and a "table" panel (public view) open together, for example with the table panel on a second display.

Initial feature areas (Proposed grouping, content to be set by R):

| Area | GM | Player |
|---|---|---|
| Operation console | requests queue, require/resolve/override checks, initiative tracker, NPC control | action requests, check results, turn status |
| Dossier | all entities | own agent sheet (attributes, skills, vitals, conditions, inventory) |
| World | scenes, NPCs, reveal/hide | revealed handouts and scenes |
| Phone | all phone threads, reply as NPC | own phone |
| Library | campaign content, import from library | read-only |
| Filing | operation log, export, archive viewer for pre-migration text (P12) | own visible log, archive viewer limited to own perspective (P12) |

## Shared UI kit (`packages/ui_kit`, P1)

Theme (the "Top Secret" dossier look), typography, the dice-breakdown widget, perspective panel scaffolding and responsive layout primitives used by both apps. It depends on Flutter and `signals_flutter`, but not on Firebase or the session, so widgets are testable with plain data.

## Platform rules

- No `dart:io` imports in shared code; platform-specific services use conditional imports keyed on `dart.library.io` / `dart.library.js_interop` [V-12].
- No `Platform.isX` checks in shared code; they throw on the web [V-12].
- Hosting capabilities differ by platform (the web build cannot host, see [04-session.md](04-session.md#play-modes)). The UI asks the session which transports are available instead of checking the platform itself.

- Desktop builds reach Firebase through `firebase_dart`: probed on Windows and Linux, the v1 desktop targets ([06-accounts-backend.md](06-accounts-backend.md#stack-fixed-adopted-by-r)). Push notifications are in-app only on Windows and Linux.
- **Windows identity.** The Windows runner's company and product names decide where `flutter_secure_storage` keeps the auth-box key (`%APPDATA%\<company>\<product>\`) [V-44]. They are set once before the first release and not changed, or every user is signed out (B5).

### Web build role (W1, Fixed for now; ruled by R 2026-10-20)

The web build is a lightweight, player-only client that reaches people who have not yet decided to install the app. There is no GM hosting on the web. R noted that GMs on the web would lose control over engine version, pack choice and modifying their own games, features most GMs would want; those live in native builds. Features are gated by a capability set the app reads at startup (for example `canHost`, `canEditPacks`), so a later change is a configuration change, not a restructure. Revisiting W1 is Pending D: see [09-open-decisions.md](09-open-decisions.md#pending-d).

## The app shell never affects outcomes (Fixed)

Concretely: no numeric rule, table or formula lives in `apps/`. Code review rejects any arithmetic on game values in a view model except formatting. Read models in the engine provide every derived number the UI shows.
