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

Theme data and the theme controller (see [Themes and player appearance settings](#themes-and-player-appearance-settings)), typography, the dice-breakdown widget, perspective panel scaffolding and responsive layout primitives used by both apps. It depends on Flutter and `signals_flutter`, but not on Firebase or the session, so widgets are testable with plain data.

## Themes and player appearance settings

Status: **T1 Fixed** (R, 2026-11-04); every detail below that T1 does not state is **Proposed**, and the open items are T2 to T8 in [09](09-open-decisions.md#open-for-r-themes). Nothing here is built: `ui_kit` still ships the placeholder `BardTheme`. Visual source material is in the project library, cited by name and not copied: `design/synthesis-government-terminal.md` (§6.0 themes, §6.1 tokens, §6.6 accessibility), `design/colorblind-palettes.md` (the 12 computed sets and the method) and `design/review-list-for-R.md` (DEC-07, DEC-25, DEC-40, VER-14).

### What R ruled (T1, Fixed)

1. Theme choice is a selectable setting on the player's profile. Read here as an account-level setting stored with the account, not a field of the public in-world profile ([11](11-supplemental-features.md#agents-aliases-and-profiles)).
2. The player picks one of the built-in themes (**Phosphor**, **Manila**, **Night Desk**) and, separately, how it renders from a drop-down: normal, high contrast, or a colour-blind mode, "if available" (R's words).
3. Each theme is self-contained: its colour-blind and contrast variants are saved together with its defaults.
4. A player can create a custom theme and set, in the UI, any colour the built-in themes set.
5. Players can import and export themes.
6. Testing with colour-blind players is still owed (VER-14).

This replaces the design review's earlier recommendation that the choice be stored locally only (DEC-25 A, DEC-40 A).

**Proposed readings of T1.** "If available" is read as: the drop-down lists only the variants the chosen theme provides. T1 says nothing about the GM forcing a theme or variant; this design gives the GM no override (T4). The design review's intrusion effects that might do so (DEC-07) stay unruled.

### Theme document

A theme is one plain JSON-shaped document. Built-in and custom themes use the same shape and the same validator.

| Field | Type | Notes |
|---|---|---|
| `format` | `"bard-theme"` | Marks the file type |
| `schemaVersion` | int | `1` for this design. Bumped only by a code change, with a migration of stored themes |
| `id` | string | Built-ins: `phosphor`, `manila`, `night-desk` (reserved). Custom: generated locally |
| `name` | string | 1 to 40 characters, shown as plain text |
| `basedOn` | string, optional | The theme it was duplicated from; information only |
| `brightness` | `"dark"` \| `"light"` | Hint for the Flutter brightness and platform chrome. Phosphor and Night Desk dark, Manila light (§6.0) |
| `variants` | object | Keys from `normal`, `highContrast`, `redGreenSafe`, `blueYellowSafe`. `normal` is required. The keys present are the variants the theme provides |

Each variant holds the **complete** token map, with no inheritance between variants: that is what makes a theme self-contained (T1 point 3) and keeps validation simple. A full four-variant theme is about 4 to 5 KiB of JSON (estimate: 33 tokens of about 25 bytes per variant, not measured).

**Tokens.** Names as in the synthesis §6.1, plus chip tokens. Values are `#RRGGBB`.

| Group | Tokens (§6.1 names) |
|---|---|
| Surfaces | `desk`, `window`, `windowRaised`, `labelCell` |
| Lines and text | `rule`, `ink`, `inkMuted` |
| Interaction | `signal`, `signalFill`, `onSignalFill` |
| Paper | `paper`, `paperInk`, `paperAlert` |
| Redaction | `redact` |
| Status | `lineOk`, `lineDown`, `markLow`, `markMid`, `markHigh` |
| Functional hues | `supervisor`, `anomaly` |
| Result and state chips (fill / text) | `success` / `onSuccess`, `partial` / `onPartial`, `failure` / `onFailure`, `warning` / `onWarning`, `locked` / `onLocked`, `confirm` / `onConfirm` |

§6.1 and the study name the chips by outcome (success, partial, failure, warning, locked, confirm) and give each a fill and a text colour. The `on…` names are Proposed (T7). There are 33 tokens per variant.

**Built-in values.** Chrome, paper and status tokens come from §6.1. Chip values for each variant come from `colorblind-palettes.md`: Default goes in `normal`, High contrast in `highContrast`, Red-green safe in `redGreenSafe` and Blue-yellow safe in `blueYellowSafe`. In the built-ins the four variants differ only in the five state chips; chrome, paper and `confirm` are the same in every variant (§6.1, study §1). The built-ins ship as JSON assets in this schema, the way `content_core` ships its pack (CLAUDE.md §9), so D can edit them without touching Dart.

**Rendering rules that are not tokens** (§6.1, §6.6): every chip has a 1 px `ink` outline (`paperInk` on paper), 2 px in `highContrast`. Every result and state chip always shows its glyph and word (check mark in a square and SUCCESS, half-filled diamond and PARTIAL SUCCESS, cross in a circle and FAILURE, triangle and WARNING, padlock and LOCKED). The redaction bar keeps its 1 px `rule` outline on dark themes. No token can remove a glyph, a word or an outline.

### The player's setting

The setting is `{ themeId, variant, updatedAt }`.

Resolution, in order:

1. Find `themeId` among the built-ins and the player's custom themes. If it is missing (deleted, not yet synced, or failed validation on load), render the first-launch default and say so on the settings screen. The stored setting is not overwritten, so a later sync can restore it.
2. If the theme provides `variant`, use it. Otherwise render `normal`, and the drop-down shows the note "*Variant* is not available in this theme; using Normal". The stored `variant` is kept, so a Red-green safe choice comes back when the player returns to a theme that has it.
3. Validation guarantees every variant has all 33 tokens, so widgets never see a missing token.

**First launch** (Proposed, DEC-25 A): follow the OS brightness, dark gives Night Desk and light gives Manila, with variant `normal`. The brightness comes from the platform through Flutter `MediaQuery` [U].

### Where it is stored

- **Anonymous (tier 0):** on the device only, in the small account/cache database (09-3; `sembast_web` on the web player). Tier 0 has no `agents` document or profile ([12](12-firestore-collections.md#agentsuid-private), [11](11-supplemental-features.md#agents-aliases-and-profiles)). It is lost when local storage is cleared [V-8], like the rest of an anonymous account.
- **Full accounts:** an account-level setting that syncs between devices (not part of the public profile). The local copy is always what renders, so play works offline. **Proposed location (T2, needs R):** a separate owner-only document, `appearance/{uid}`, holding `themeId`, `variant`, `updatedAt` and a `themes` map of the player's custom themes. `agents/{uid}` is not used, because its rules whitelist exactly the owner-editable personal fields with `keys().hasOnly` ([12](12-firestore-collections.md#agentsuid-private)), and that whitelist stays as it is. One document is one read at sign-in. Desktop has no live listeners [V-47], so it is refetched at sign-in and when settings open. Draft rule `[U]`: `get`, `create`, `update` and `delete` only if `isFull() && id == uid()`, with `keys().hasOnly(['themeId','variant','updatedAt','themes'])` and a cap on `themes.size()`. The rules do not check colours. The app validates every theme it loads, from the server or anywhere else.
- **Upgrade and conflicts (Proposed):** on the first full sign-in, a local setting with no server document is uploaded. Afterwards the newer `updatedAt` wins for the setting, and custom themes are merged by id, up to the cap.
- **Privacy (conflict, T2):** a colour-blind variant can reveal a real person's vision condition. [11](11-supplemental-features.md#real-personal-data) limits real personal data to a fixed list and says consent covers only those fields, so a synced variant sits outside that list. Options: (a) store it as a neutral rendering label (`variant`) with no health framing anywhere in the data or the UI, owner-only and never used for anything but rendering; (b) keep the variant local-only and sync only the theme; (c) amend 11's list and the consent screen. Recommended: (a), because the label records a display preference, not a diagnosis, and anyone can pick any variant. Either way the document is owner-only, never public, never indexed, and never visible to the GM. R rules.

### Custom themes

- **Create** by duplicating a built-in or another custom theme. The copy takes every variant the source provides. Built-ins are read-only.
- **Edit** every token in every variant the custom theme provides. The player can remove variants other than `normal`. Input is hex entry with a swatch, plus the source theme's own colours as quick picks. A colour-picker package would need R's approval (CLAUDE.md §6).
- **Live preview:** a pane renders a sample window, a record table, all six chips with glyphs and words, a paper sample, line status, marks, supervisor and anomaly, using the map being edited. Nothing changes outside the pane until Save.
- **Advisories, never blocking.** The editor runs the study's checks, with the same methods and thresholds: WCAG 2.x contrast (4.5:1 for text, 3:1 for large text, UI parts and a chip against `window`), and CIEDE2000 differences after the Machado et al. (2009) severity 1.0 simulation in linear RGB (result chips 15 apart in normal, protan, deutan and tritan vision; 18 from chrome fills, `anomaly` and `supervisor` in normal vision only, rule d; `confirm` and Warning and Locked 15 from the result chips). Achromatopsia is checked only in `highContrast`. Each failing pair shows a warning next to the token and in a summary. The player can still save and apply.
- **Reset cannot be lost.** The appearance settings and the editor draw their own chrome in a built-in theme (the custom theme's source, or the first-launch default); only the preview pane uses the custom colours. Applying a custom theme asks for confirmation and reverts after 15 seconds without an answer. "Reset to built-in theme" stays on the settings screen and in the app menu, reachable by keyboard. A bad custom theme therefore cannot hide the way back.

### Import and export

- **Export** writes one theme as a JSON file in the schema above. Built-ins can be exported too, as a starting point. The web player uses a browser download. Native builds use a save dialog. The file-dialog package (picker and save) is proposed to R before implementation and is not chosen here.
- **Import** reads a file through a file picker (on the web, the browser's). It validates the file in this order, and it reports every problem at once with its JSON path, as the pack loader does:
  1. Size at most the cap (T3) before parsing; must be valid JSON.
  2. `format` is `bard-theme`; `schemaVersion` is a version this build knows. An unknown version is rejected with "made by a newer version".
  3. Only the fields above are allowed. Unknown fields, unknown variant keys and unknown tokens are errors; `normal` is required; every variant has all 33 tokens.
  4. Every colour matches `#RRGGBB` (any case; stored upper case). Anything else is rejected, never clamped or guessed, so a file never shows colours other than the ones it contains (T7).
  5. `name` is trimmed, control and bidirectional-override characters are removed, the length is checked, and it is always displayed as plain text, never as markup or a link.
- **Data only.** The schema has no field for a URL, script, asset path, image or font, and unknown fields are rejected, so importing never fetches or runs anything.
- **Import creates a copy** with a new local id. It never overwrites a built-in or an existing custom theme; a duplicate name gets a suffix (" (2)"). An import is refused at the custom-theme cap. The advisory checks run on the imported theme.
- **Sharing:** themes are personal files. Players can pass files to each other outside the app. v1 has no public gallery or in-app upload, so no public content and no moderation queue are involved (T5).

### Limits (Proposed, T3)

| Limit | Proposed | Why |
|---|---|---|
| Custom themes per player | 20 | Personal use. 20 × about 5 KiB is about 100 KiB, a tenth of Firestore's 1 MiB document cap [V-7], which leaves room for schema growth |
| Import file size | 32 KiB | About six times a full pretty-printed theme. The file is rejected before parsing |
| Theme name | 40 characters | Fits a drop-down row |

### Layering

- **`ui_kit`** (Flutter and `signals_flutter` only, no Firebase or session): the theme data classes (`ThemeDocument`, `ThemeVariant`, the token class), the hand-written JSON codec and validator (P6 style), the contrast and colour-difference math as pure Dart files with no Flutter import, the built-in theme assets (placement of the codec, validator and math is T8: [00](00-overview.md) describes `ui_kit` as Flutter widgets and theme only), the settings and editor widgets, and a `ThemeController` that exposes the resolved tokens as a signal and maps them to Flutter `ThemeData` plus a theme extension for the custom tokens [U]. If R prefers, the controller can live in each app instead.
- **Apps:** an `AppearanceRepository` in `data/repositories` over the local store and the backend gateway, built in `composition.dart`. View models read and write through it (layering above; CLAUDE.md §8). The companion app uses the same `ui_kit` pieces.
- **Engine, protocol and session are untouched.** Appearance is presentation only: it is never a command or event, never in the event log or text log, and never sent to other participants. Theme settings are never a gateable shell capability for the GM (synthesis §12.7, Proposed there).
- **W1:** the web player gets the whole feature (settings, custom themes, import and export). Nothing here is hosting, so no capability gate applies.

### Accessibility, and what is not guaranteed

- The built-in variants pass the study's hard rules a to e (`colorblind-palettes.md` §1, §2.4). Achromatopsia separation is required of `highContrast` only. Warning falls below 15 dE from the result chips in three built-in sets (Manila Default, Manila Blue-yellow safe, Night Desk High contrast); there the glyph and word carry it.
- The figures come from a simulation, not from people. Testing with colour-blind users is owed: VER-14, defined in the project library's design review (`design/review-list-for-R.md`) and recorded in [09](09-open-decisions.md#still-unproven) as the repo's entry. Values may change after it.
- Custom and imported themes are not guaranteed accessible. The advisories inform the player and do not block.
- Not covered: OS forced-colours and high-contrast modes, print (paper documents use the paper tokens), and colour shifts from texture, anti-aliasing and display calibration (study §6). Text size, reduced motion and the signal texture are separate settings (§6.3, §6.5, §6.6), not part of a theme.
- "High contrast" here is the study's result-chip set; it does not raise the chrome's contrast.

### Tests to write

- **Unit, codec and validator:** a round trip for each built-in; one failing case per error class (oversize, bad JSON, wrong `format`, unknown `schemaVersion`, unknown field, missing `normal`, missing token, unknown token, non-hex and 3-digit and alpha colours, control characters in `name`), each with its JSON path; every problem reported in one pass; a URL or script string in an unknown field is rejected as an unknown field.
- **Unit, resolution:** missing theme gives the first-launch default and keeps the stored setting; missing variant gives `normal` and keeps the stored variant; switching back restores the variant; dark and light OS brightness pick Night Desk and Manila.
- **Unit, colour math:** contrast reproduces the palette-card figures (`#04650D` against white 7.31, `#DCBFA6` against black 12.05, `#0072B2` against white 5.19); CIEDE2000 matches the published Sharma, Wu and Dalal (2005) test pairs; simulated differences reproduce the study's tables (for example Phosphor Default success-partial 52.0 under deuteranopia); the advisories on the built-ins are exactly the study's known exceptions and nothing else.
- **Unit, repository:** with fake stores, the anonymous account never writes to the backend; upgrade uploads; the newer `updatedAt` wins; the merge respects the cap; import never replaces a built-in.
- **Widget:** the variant drop-down lists only what the theme provides, and an unavailable stored variant shows the note; editing a token updates only the preview until Save; a failing advisory shows and Save stays enabled; settings chrome stays readable under a deliberately unreadable custom theme; the timed revert fires; Reset is reachable by keyboard; every chip shows glyph and word in every built-in variant and in a custom theme.
- **Rules (Emulator Suite, if T2 is ruled as proposed):** owner-only access; an anonymous token is refused; the field whitelist; the cap on `themes`.

### Open questions

| # | Question | Owner |
|---|---|---|
| T2 | Storage: `appearance/{uid}` or another place, and the conflict rule. Privacy conflict with 11's real-data list (a variant may reveal a vision condition): neutral label (recommended), local-only variant, or amend 11 | R |
| T3 | Limits: custom-theme count, file size, name length | R |
| T4 | Can the GM ever force a theme or variant (for example as a DEC-07 intrusion with player opt-out, DEC-16)? T1 is silent; Proposed: no override | R, with D for the game effect |
| T5 | Community sharing or a public theme gallery; it would go through 11's moderation | R and D |
| T6 | May custom themes change the paper tokens? Paper is a fiction object, identical in every built-in theme (§6.1); T1 point 4 reads as allowing it | R, with D for the fiction |
| T7 | Confirm the Proposed details: `on…` chip token names; Manila's outer-edge rule colour (§6.1) as its own token or not; reject rather than clamp bad colours; first-launch default per DEC-25 A; the wording of the variant labels; the "only the variants the theme provides" reading of "if available" | R; D on the wording |
| T8 | Where the pure-Dart theme codec, validator and colour math live. [00](00-overview.md) describes `ui_kit` as Flutter widgets and theme only. Options: amend 00 to allow them in `ui_kit`, or put them in a separate Flutter-free package, as F4 did for the wire format. Recommended: amend 00 and keep them as Flutter-free files inside `ui_kit`; a new package for one small model adds a layer for little gain, and moving later stays cheap | R |

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
