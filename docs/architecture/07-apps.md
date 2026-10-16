# 07. Applications

## The three apps

| App | Platforms (Fixed scope) | Who | Role |
|---|---|---|---|
| `apps/bard` | all Flutter targets; designed for landscape medium/large screens | GM and players | Full GM experience and full player experience |
| `apps/companion` | phones (built in parallel) | players first | Character sheet, checks, in-game phone, notifications; joins operations the main app hosts |
| `apps/server` | Cloud Run (Dart) | none directly | Relay, badge sign-in, pack publishing, library verification hooks |

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
    routes.dart                    routing (Open decision)
  main.dart
```

- View models talk to repositories; repositories wrap services. The `session` package is used through a service, so view models never see actors or transports.
- View models expose **commands** (Flutter guide terminology for user-intent callbacks [V-2]). A command such as `requestLockpick()` turns into an engine command sent through the session. It never computes an outcome.
- The state-management mechanism view models use is an open decision ([09-open-decisions.md](09-open-decisions.md#1-state-management)). This layout works with each option there.

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
| Filing | operation log, export | own visible log |

## Shared UI kit (Proposed `packages/ui_kit`)

Theme (the "Top Secret" dossier look), typography, the dice-breakdown widget, perspective panel scaffolding and responsive layout primitives used by both apps. It depends on Flutter but not on Firebase or the session, so widgets are testable with plain data.

## Platform rules

- No `dart:io` imports in shared code; platform-specific services use conditional imports keyed on `dart.library.io` / `dart.library.js_interop` [V-12].
- No `Platform.isX` checks in shared code; they throw on the web [V-12].
- Hosting capabilities differ by platform (a web GM cannot host LAN, see [04-session.md](04-session.md#play-modes)). The UI asks the session which transports are available instead of checking the platform itself.
- Desktop backend access depends on the open concern in [09-open-decisions.md](09-open-decisions.md#concerns-raised).

## The app shell never affects outcomes (Fixed)

Concretely: no numeric rule, table or formula lives in `apps/`. Code review rejects any arithmetic on game values in a view model except formatting. Read models in the engine provide every derived number the UI shows.
