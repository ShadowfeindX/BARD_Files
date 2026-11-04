# 07. Applications

## The three apps

| App | Platforms | Who | Role |
|---|---|---|---|
| `apps/bard` | v1: Windows and Linux desktop, plus the player-only web build; designed for landscape medium/large screens | GM and players | Full GM experience and full player experience on native builds. The web build is player-only ([below](#web-build-role)) |
| `apps/companion` | phones (built in parallel) | players first | Character sheet, checks, in-game phone, notifications; joins episodes the main app hosts |
| `apps/functions` | Firebase, HTTPS-only Dart Cloud Functions (experimental) | none directly | Badge login, role claims, payment webhook, store receipt validation, push, pack publishing helper (planned; scaffold only today, 10 §5). Depends only on `protocol_envelope`, never on the engine. No relay: Realtime Database is the relay |

Both Flutter apps use the same `session`, `engine` and `protocol` packages, so a companion phone and a tablet are equal participants in an episode. The companion app is a different **UI**, not a different client.

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
    routes.dart                    routing (go_router)
  main.dart
```

- View models talk to repositories; repositories wrap services. The `session` package is used through a service, so view models never see actors or transports.
- View models expose **commands** (Flutter guide terminology for user-intent callbacks [V-2]). A command such as `requestLockpick()` turns into an engine command sent through the session. It never computes an outcome.
- **State management:** Dart Signals, through `signals_flutter` 7.1.0 (publisher rodydavis.com; Flutter bindings over `signals_core`) in `apps/` and `ui_kit` [V-29]. The umbrella `signals` package is not used; the engine stays SDK-only. View models expose signals, and views read them.
- **Routing:** `go_router` 18.1.1 [V-30], with `app_links` 7.2.2 as the desktop link companion that delivers links to the router. The canonical join link is `bard://join/<campaignId>?invite=<token>` (Proposed, open: [Deep-link join](10-waiting-on-d.md#deep-link-join)), which every target can register; https links come later where supported. The V-30 live check on Linux and Windows covered the earlier `bard://join/<op>?alias=<id>` form only [V-30]. Link delivery is planned (`app_links` is pinned, not wired; 10 §5 'Deep-link join'). Android https links, when added, need `assetlinks.json`.
- **Persistence:** sembast (+ `sembast_web` for web player caches) behind the session's `EventStore` (planned; only `InMemoryEventStore` today, 10 §5), see [04-session.md](04-session.md#interfaces-the-session-depends-on).
- Package versions are re-verified on pub.dev before each enters a pubspec.

## Perspective panels

The main app shows per-perspective panels: what the GM sees and what players see. Each panel binds to one perspective stream from the session ([04-session.md](04-session.md#perspectives)). A GM on a large screen can keep the GM panel and a "table" panel (public view) open together, for example with the table panel on a second display.

Initial feature areas (Proposed grouping, open: [S-3](09-open-decisions.md#s-3-perspective-panel-feature-areas)):

| Area | GM | Player |
|---|---|---|
| Episode console | requests queue, require/resolve checks, review consequence batches, initiative tracker, NPC control | action requests, check results, turn status |
| Dossier | all entities | own agent sheet (attributes, skills, vitals, conditions, inventory) |
| World | scenes, NPCs, reveal/hide | revealed handouts and scenes |
| Phone | all phone threads, reply as NPC | own phone |
| Library | campaign content, import from library | read-only |
| Filing | episode log, export, archive viewer for pre-migration text | own visible log, archive viewer limited to own perspective |

## Shared UI kit (`packages/ui_kit`)

Built today: the dice-breakdown widget, the perspective panel, the phone panel and a placeholder `BardTheme`. Planned (10 §5 'Theme build'): the theme widgets and theme controller over the pure-Dart theme package `theme_core` (see [Themes and player appearance settings](#themes-and-player-appearance-settings)), typography and responsive layout primitives used by both apps. It depends on Flutter, `signals_flutter` and (once built) `theme_core`, but not on Firebase or the session, so widgets are testable with plain data.

## Themes and player appearance settings

Anything in this section that is not stated under "What the theme system provides" is **Proposed**; the provides list includes the colour format and the separate package; the open parts are the `windowEdge` values and the `theme_core` name ([T11](09-open-decisions.md#t11)). Each Proposed detail carries the id of its open item: [T3](09-open-decisions.md#t3) (theme document and fields, token sets and version map, resolving a theme, fallback, value lookup, chain checks, derived themes, custom-theme safeguards, import and export, export flattened by default, the stored setting shape and its resolution steps, and the colour format flatten and export write); [T4](09-open-decisions.md#t4) (outdated themes, effect safety, effect tokens); [T6](09-open-decisions.md#t6) (documents); [T11](09-open-decisions.md#t11) (`windowEdge`, the package name); [S-4](09-open-decisions.md#s-4-how-the-built-in-theme-json-ships) (how the built-in theme JSON ships); [S-9](09-open-decisions.md#s-9-gateable-shell-capabilities) (theme settings are not a gateable capability). Where the open items are listed: [T2](09-open-decisions.md#t2), [T3](09-open-decisions.md#t3), [T4](09-open-decisions.md#t4), [T6](09-open-decisions.md#t6), [T10](09-open-decisions.md#t10) and [T11](09-open-decisions.md#t11) in [09](09-open-decisions.md#open-for-r-themes); [T5](09-open-decisions.md#t5) and [T7 e](09-open-decisions.md#t7) (the label wording) are [Pending D](09-open-decisions.md#pending-d). Nothing here is built: `ui_kit` still ships the placeholder `BardTheme`. Visual source material is in the project library, cited by name and not copied: `design/synthesis-government-terminal.md` (§6.0 themes, §6.1 tokens, §6.6 accessibility, §7.6 shell states, §10 Forms and filing, §12 shell gating, pattern rows P15, P33, P34 and P49), `design/colorblind-palettes.md` (the 12 computed sets and the method) and `design/review-list-for-R.md` (DEC-07, DEC-29, DEC-34, VER-14).

### What the theme system provides

1. Theme choice is a selectable setting of the player. It is not a field of the public in-world profile ([11](11-supplemental-features.md#agents-aliases-and-profiles)), and it is stored on the client ([Where it is stored](#where-it-is-stored)).
2. The player picks one of the built-in themes (**Phosphor**, **Manila**, **Night Desk**) and, separately, how it renders from a drop-down: normal, high contrast, or a colour-blind mode. The drop-down lists only the variants the chosen theme provides (Proposed, open: [T3](09-open-decisions.md#t3)).
3. Each theme is self-contained: its colour-blind and contrast variants are saved together with its defaults.
4. A player can create a custom theme and set, in the UI, any colour the built-in themes set.
5. Players can import and export themes. In v1 they share themes only outside the app, as exported files (open: [T5](09-open-decisions.md#t5)).
6. There are no limits on player theming: no cap on the number of custom themes, on name length or on overrides. A theme may name a **base** theme and store only the values it overrides. The design for this is under [Derived themes](#derived-themes-base-and-overrides-proposed-open-t3) (Proposed, open: [T3](09-open-decisions.md#t3)).
7. The Handler cannot force a change from one theme to another, and since a variant is part of a theme, cannot force a variant either (the variant part is Proposed, open: [T4](09-open-decisions.md#t4)). The Handler can force certain screen colours, highlights or effects that other game features describe (capability lock cards, synthesis §12, revision 4, with [DEC-34 and GAP-33](09-open-decisions.md#dec-34-and-gap-33-capability-lock-cards) undecided; intrusion cues, [DEC-07](09-open-decisions.md#dec-07-intrusion-cues) undecided). The colours for those are part of every palette ([Effect and highlight tokens](#effect-and-highlight-tokens)). A theme that lacks a colour a newer feature needs is completed from a built-in ([Outdated themes](#outdated-themes-proposed-open-t4); Proposed, open: [T4](09-open-decisions.md#t4)). Whether and how intrusions happen is not decided here.
8. All documents will eventually be rendered by an in-house pipeline (typst or another solution), so documents may be affected by theme. Document colours are tokens in every palette and custom themes may change them. A document mode switch shows the standard, fixed scheme ([Documents and document mode](#documents-and-document-mode-proposed-open-t6)).
9. The chip text tokens are named `onSuccess`, `onPartial`, `onFailure`, `onWarning`, `onLocked` and `onConfirm`. The window edge has its own token, `windowEdge`, set on every built-in theme and variant ([Window edge](#window-edge)). Invalid themes are rejected on import; the colour format is in [Colour format](#colour-format).
10. The first-launch default follows the OS brightness, as a **System** option in the theme selector ([The player's setting](#the-players-setting)). The variant labels are Normal, High contrast, Red-green safe and Blue-yellow safe; the label wording is open ([T7 e](09-open-decisions.md#t7)).
11. The theme model is a separate package, so that it can grow after v1 (theme distribution, per-campaign theme settings, custom icons, images, animations) ([Layering](#layering)). Its name `theme_core` is Proposed (open: [T11](09-open-decisions.md#t11)).
12. Testing with colour-blind players is owed (VER-14).
13. The colour format is `#RRGGBB` for every token; `#RRGGBBAA` only on alpha-capable tokens, alpha is rejected elsewhere, and contrast is computed on the composited colour ([Colour format](#colour-format)).

Whether the Handler console follows the same appearance setting as the player experience is open ([T2](09-open-decisions.md#t2)).

### Theme document (Proposed, open: T3)

A theme is one plain JSON-shaped document. Built-in, custom and imported themes use the same shape and the same validator. A theme is either **full** (it stores complete token maps in `variants`) or **derived** (it names a `base` and stores sparse `overrides`).

| Field | Type | Notes |
|---|---|---|
| `format` | `"bard-theme"` | Marks the file type |
| `schemaVersion` | int | `1` for this design. The document shape. Bumped only by a code change, with a migration of stored themes |
| `tokenSet` | int | The token set the theme was made for ([Token sets](#token-sets-proposed-open-t3)). Required in every theme |
| `id` | string | Built-ins: `phosphor`, `manila`, `night-desk`; `system` is also reserved (the selector option, never a document). Custom: a random UUID generated locally, so a file can name it as a base on another client |
| `name` | string | Not empty after trimming; no length cap. Long names are shortened with an ellipsis in lists, shown in full in the editor, always as plain text |
| `copiedFrom` | string, optional | The theme a full theme was duplicated from. Used only to find the fallback built-in ([Fallback built-in](#fallback-built-in-proposed-open-t3)) |
| `brightness` | `"dark"` \| `"light"` | Hint for the Flutter brightness and platform chrome, and the last resort for the fallback built-in. Phosphor and Night Desk dark, Manila light (§6.0) |
| `variants` | object, full themes only | Keys from `normal`, `highContrast`, `redGreenSafe`, `blueYellowSafe`. `normal` is required. Each value holds every token of the theme's `tokenSet`. The keys present are the variants the theme provides |
| `base` | object, derived themes only | `{ "id": <base theme id>, "tokenSet": <the base's tokenSet when this theme was derived or last saved> }`. Names a built-in or custom theme ("a named or default theme") |
| `overrides` | object, derived themes only | Same variant keys as `variants`. Each value is a **sparse** token map: only the tokens this theme changes. An empty map declares the variant without changing anything |

A document has either `variants` or both `base` and `overrides`, never both forms.

**Self-contained.** Built-in and full themes store every variant's complete map in one document. A derived theme is self-contained in the sense that all its variants are stored together in one document; its base reference is resolved locally on each client. Export writes a flattened, fully self-contained file by default ([Import and export](#import-and-export-proposed-open-t3)).

**Size (estimate, not measured).** A full four-variant theme holds about 4 KiB of token entries (42 tokens of about 25 bytes, times four variants) plus a few hundred bytes of structure. A derived theme that changes three colours in two variants is a few hundred bytes. Nothing is synced, so this matters for local storage and file sharing, not for a server document cap.

### Tokens (token set 1)

Names as in the synthesis §6.1, plus chip text tokens, the window edge, effect tokens and document tokens. **Every token has a built-in value in every variant of every built-in theme**, so any theme can be completed from a built-in.

| Group | Tokens |
|---|---|
| Surfaces | `desk`, `window`, `windowRaised`, `labelCell` |
| Lines and text | `rule`, `windowEdge`, `ink`, `inkMuted` |
| Interaction | `signal`, `signalFill`, `onSignalFill` |
| Documents | `paper`, `paperInk`, `paperAlert` (§6.1); `paperInkMuted`, `paperRule`, `paperStamp`, `paperRedact` (Proposed, open: [T6](09-open-decisions.md#t6)) |
| Redaction | `redact` |
| Status | `lineOk`, `lineDown`, `markLow`, `markMid`, `markHigh` |
| Functional hues | `supervisor`, `anomaly` |
| Result and state chips (fill / text) | `success` / `onSuccess`, `partial` / `onPartial`, `failure` / `onFailure`, `warning` / `onWarning`, `locked` / `onLocked`, `confirm` / `onConfirm` |
| Effects and highlights | `highlight`, `intrusionGround`, `onIntrusionGround`, `sceneTint` (all Proposed, open: [T4](09-open-decisions.md#t4)) |

§6.1 and the study name the chips by outcome (success, partial, failure, warning, locked, confirm) and give each a fill and a text colour. The six outcome `on…` names are new; `onSignalFill` is already in §6.1. There are 42 tokens per variant.

**Built-in values.** Chrome, paper and status tokens come from §6.1. Chip values for each variant come from `colorblind-palettes.md`: Default goes in `normal`, High contrast in `highContrast`, Red-green safe in `redGreenSafe` and Blue-yellow safe in `blueYellowSafe`. In the built-ins the four variants differ only in the five state chips (`success`, `partial`, `failure`, `warning`, `locked` and their text colours). Chrome (including `windowEdge`), paper, `confirm` and the four new effect tokens are the same in every variant (§6.1, study §1). The built-ins ship as JSON assets of the theme package ([Layering](#layering); Proposed, open: [S-4](09-open-decisions.md#s-4-how-the-built-in-theme-json-ships)), so D can edit them without touching Dart (CLAUDE.md §9).

#### Window edge

§6.1 gives Manila's outer window edges their own colour (beige shade 57 `#5F5348`, 4.28:1 on `desk`) but no token; the other themes have none. `windowEdge` is the 1 px outer border of every window: it meets the desk outside, the window body inside and, along the top, the title bar (`windowRaised`). The surface colours are the §6.1 values in the project library's design synthesis (not in this repository), and the edge candidates are steps of each theme's official ladder (the palette cards, §6.0). Each value was chosen to reach at least 3:1 against `desk`, `window` and `windowRaised`; the figures below are WCAG 2.x contrast ratios **computed from the design library values** for this spec (Python, 2026-11-04):

| Theme | Value (ladder step) | vs `desk` | vs `window` | vs `windowRaised` (title bar) | Same in all four variants |
|---|---|---|---|---|---|
| Phosphor | `#C0D8C2` (green tint 75) | 12.93 | 8.59 | 4.82 | yes |
| Manila | `#5F5348` (beige shade 57, §6.1) | 4.28 | 7.11 | 4.28 | yes |
| Night Desk | `#B8D8E9` (blue tint 72) | 12.81 | 9.08 | 5.57 | yes |

So the 12 values are Phosphor `#C0D8C2` in `normal`, `highContrast`, `redGreenSafe` and `blueYellowSafe`; Manila `#5F5348` in all four; Night Desk `#B8D8E9` in all four. The edge is chrome, and chrome is the same in every variant (§6.1, study §1). All three are printed steps of the palette cards. On the dark themes no step weaker than these reaches 3:1 against the title bar without landing on the interactive hue: Phosphor's tint 60 is `signal` and Night Desk's tint 54 is `signalFill`, so the edge takes the next printed step above them (contrast against `signal`: Phosphor 1.32, Night Desk 1.82, also computed; against `ink`: 1.30 for both). A light edge suits the dark themes' boxed, light-on-dark look (§6.0); Manila keeps the §6.1 value, which is also its `inkMuted`. The values are Proposed (open: [T11](09-open-decisions.md#t11)). The library's palette study (`colorblind-palettes.md`) and the synthesis §6.1 should be updated with this token; this spec does not edit the library.

#### Effect and highlight tokens

These are the colours a Handler-forced effect may use. The Handler never picks a colour or a theme; a feature uses a named token and the player's resolved theme supplies its value. Which effects exist is decided with their features (capability locks: synthesis §12, [DEC-34 and GAP-33](09-open-decisions.md#dec-34-and-gap-33-capability-lock-cards) undecided; intrusions: [DEC-07](09-open-decisions.md#dec-07-intrusion-cues) undecided).

| Token | Source | Used by | Built-in value |
|---|---|---|---|
| `locked` / `onLocked` | Design (§6.1 chip, study tables) | Lock glyph and `LOCKED` chip on a capability lock card (§12.3, P49) and on locked desktop icons | Study values, **per variant** (a state chip) |
| `warning` / `onWarning` | Design (§6.1 chip) | Warning strips on forced notices | Study values, **per variant** (a state chip) |
| `anomaly` | Design (§6.1: "Paranatural intrusions only") | Accent of an intrusion cue (DEC-07, once decided) and corrupted-content marks inside a window (P34) | §6.1, same in every variant |
| `supervisor` | Design (§6.1: Handler chrome accent) | `SET BY HANDLER` line and Handler-set labels | §6.1, same in every variant |
| `rule`, `ink`, `inkMuted` | Design (§7.6 lock card anatomy) | Lock card box, reason text, time and setter | §6.1, same in every variant |
| `highlight` | **Proposed, new** (open: [T4](09-open-decisions.md#t4)) | A Handler highlight of a field, record or window: a 2 px outline plus a word tag | Initially each theme's `supervisor`, same in every variant |
| `intrusionGround` | **Proposed, new** (open: [T4](09-open-decisions.md#t4)) | Ground of a full-window takeover cue (P15, only as DEC-07 allows once decided) | Initially each theme's `desk`, same in every variant |
| `onIntrusionGround` | **Proposed, new** (open: [T4](09-open-decisions.md#t4)) | Text and glyphs on `intrusionGround` | Initially each theme's `anomaly` (8.57:1 on Phosphor's `desk`, §6.1; Manila and Night Desk pairs not yet computed), same in every variant |
| `sceneTint` | **Proposed, new** (open: [T4](09-open-decisions.md#t4)) | Scene tint set by the Handler (P33), drawn at low opacity over `desk` and title bars only, never under body text | Initially each theme's `anomaly`, same in every variant; the "fixed accessible set" of tints P33 mentions is a DEC-07 detail |

The design has no values for the four new tokens. The initial values above reuse existing tokens so that no colour is invented; before they ship, each new pair is computed with the study's method (contrast and CIEDE2000 against the chips and chrome) and the names and the computed results are reported under [T4](09-open-decisions.md#t4).

**Player opt-out (Proposed, open: [T4](09-open-decisions.md#t4)).** The player's effects setting (§6.6) beats any forced effect: with effects off, a scene tint, takeover or corruption cue is not drawn and a static one-line notice with the same words appears instead. Lock cards and the highlight's word tag are not cosmetic effects (they carry state the player needs), so they always show, without motion.

#### Rendering rules that are not tokens

(§6.1, §6.6, §10.1, §12.3.) Every chip has a 1 px `ink` outline (`paperInk` on paper), 2 px in `highContrast`. Every result and state chip always shows its glyph and word (check mark in a square and SUCCESS, half-filled diamond and PARTIAL SUCCESS, cross in a circle and FAILURE, triangle and WARNING, padlock and LOCKED). The redaction bar keeps its 1 px `rule` outline on dark themes. A forced effect always carries its glyph and its words (lock glyph and reason, `SET BY HANDLER · [TIME]`, the highlight's word tag, an intrusion's label; wording open: [T7 e](09-open-decisions.md#t7)): Handler effects never depend on a custom colour to carry meaning. `sceneTint` never lowers text contrast below 4.5:1, the same rule §10.1 sets for the form watermark. No token can remove a glyph, a word or an outline.

#### Colour format

`#RRGGBB` allows no transparency. Transparency matters only for overlay-style colours: the scene tint, highlight overlays and, if they ever become tokens, glows, scanlines and window shadows (texture is a separate setting today, §6.5). So:

- Every token accepts `#RRGGBB`.
- Only tokens marked **alpha-capable** in the token registry also accept `#RRGGBBAA`. In token set 1 these are `sceneTint` and `highlight`. A later token set may mark new overlay tokens (for example a shadow or glow token) the same way.
- Alpha anywhere else is rejected on import, never stripped or guessed.
- Contrast checks for an alpha-capable token use the colour composited over the surface it is drawn on.
- Flatten and export write each value in the format it was stored in; built-ins keep their exact values (Proposed, open: [T3](09-open-decisions.md#t3)).

### Token sets (Proposed, open: T3)

- **Token set 1** is the 42 tokens above. There is no token set 0.
- Each later set only adds tokens. The token registry in the theme package lists every token with the set that introduced it, whether it is alpha-capable, and the app version that first shipped that set. The registry is the version map the notices below use ("added in version *X*").
- A full theme declares the `tokenSet` it was made for and must contain every token of that set in each variant; validation rejects one that does not. Tokens introduced after its set are allowed to be missing and are filled ([Outdated themes](#outdated-themes-proposed-open-t4)).
- A derived theme's `overrides` may hold any token known to the build, whatever its `tokenSet`.

### Resolving a theme (Proposed, open: T3)

The resolver turns (theme, variant) into a complete 42-token map. It runs on load, after every edit and after any theme it depends on changes. Widgets only ever see the resolved map.

#### Fallback built-in (Proposed, open: T3)

Every theme has one **fallback built-in**, used for lookup step 3, outdated fills, effect-safety substitution and the editor's own chrome:

1. the built-in at the root of the theme's base chain, if the chain resolves to a built-in;
2. otherwise, for a full theme (or a chain ending in one), the built-in its `copiedFrom` leads to, followed the same way;
3. otherwise the built-in chosen by `brightness` (dark: Night Desk, light: Manila).

So a theme derived from or duplicated from Phosphor falls back to Phosphor, keeping §6.1's rule that `anomaly` differs from Phosphor's green text.

#### Value lookup (Proposed, open: T3)

For each token in the chosen variant `v`:

1. The theme's own value for `v` (`variants[v]` or `overrides[v]`).
2. The base theme's value for `v`, then the base's own base, and so on up the chain.
3. The fallback built-in's value for `v`, if it provides `v`.
4. The fallback built-in's `normal` variant.

Step 4 always has every token, so the map is always complete.

#### Chain checks (Proposed, open: T3)

- **Cycle:** the resolver follows base ids from the theme being resolved and stops at the first id it has already visited. Every theme on the loop is flagged "Base themes loop" and resolves as if its base were missing (no link inside the loop is followed). The editor refuses to save a base choice that would create a cycle, and an import that would create one is checked ([Import and export](#import-and-export-proposed-open-t3)).
- **Depth:** a technical safeguard against corrupt data, not a theming limit: a chain longer than the ceiling in [Technical safeguards](#technical-safeguards-proposed-open-t3) resolves as if its base were missing and is flagged.
- **Base not installed:** tokens fall through to steps 3 and 4 and the player is told: "Base theme *name or id* is not installed on this device; built-in default colours are used". The overrides are kept; installing the base later (importing it with the same id) restores the intended look. The theme list and editor offer **Flatten** to keep the current look as a full theme. The variant drop-down lists the variants the resolved theme can fully produce after fallback (the keys in `overrides` plus the fallback built-in's variants), each flagged "base missing".

#### Outdated themes (Proposed, open: T4)

A custom, imported or older derived theme can lack a token that a newer Handler or UI feature needs.

- **What counts as missing:** after the whole chain is resolved (steps 1 and 2), a token is missing only if no theme in the chain has a value for it and it had to come from the fallback built-in (steps 3 and 4). A derived theme whose chain ends in a built-in therefore never counts as outdated; its base supplied the value. A full theme on token set *n* lacks exactly the tokens introduced after *n*.
- **Fill:** missing tokens come from the fallback built-in, same variant, else `normal`.
- **Notice:** the theme list and the editor show "This theme lacks colours added in version *X*; defaults used", with *X* from the token registry, only when at least one token is missing.
- **Add missing colours:** one click copies the fallback values of the still-missing tokens into the custom theme for editing: into each variant of a full theme (raising its `tokenSet`), or as overrides of a derived theme for those tokens only. Values the base chain supplies are never copied, so a derived theme keeps following its base. If the missing tokens belong to a custom base, the notice points to that base.
- Built-ins never lack tokens.

#### Effect-safety rule (Proposed, open: T4)

Some pairs carry meaning the player must always be able to read. After lookup, these pairs are contrast-checked against the resolved surface they sit on:

| Element | Pairs (foreground on surface) | Minimum |
|---|---|---|
| State chips | `onLocked` on `locked`, `onWarning` on `warning` | 4.5:1 |
| Lock card (§7.6) | `ink` and `inkMuted` on `window`; `rule` on `window` (box) | 4.5:1 text, 3:1 box |
| Highlight, Handler labels, intrusion accent | `highlight` on `window` (3:1); `supervisor` and `anomaly` on `window` (4.5:1) | as stated |
| Takeover cue | `onIntrusionGround` on `intrusionGround` | 4.5:1 |
| Scene tint | `ink` on `desk` with `sceneTint` composited | 4.5:1 |
| Documents | `paperInk`, `paperInkMuted`, `paperAlert`, `paperStamp` on `paper`; `paperRule` on `paper` | 4.5:1 text, 3:1 rules |

**These minimums are mandatory for these elements only.** If a pair fails, the element that draws it (that lock card, that chip, that document view) uses the fallback built-in's value for the foreground, same variant, else `normal`. If the pair still fails because the surface itself is custom, that element also draws its own surface from the fallback built-in. The token keeps the player's value everywhere else: the substitution happens only inside the effect element or document, never in the theme. A forced effect or a document is therefore never invisible or unreadable, whatever the custom theme. Substitutions are listed in the editor's advisory summary. Everywhere else, the same thresholds are **advisories** only ([Custom themes](#custom-themes-proposed-open-t3)): the player is told and can still save.

### Derived themes (base and overrides) (Proposed, open: T3)

- **Create:** "New theme from…" offers **Duplicate** (a full copy of every variant, `copiedFrom` set) or **Derive** (a derived theme with the source as `base` and empty overrides). Built-ins are read-only and can be the base of any theme.
- **Inherited and overridden values:** the editor shows each token, per variant, as *inherited* (with the theme it comes from, for example "from Night Desk", in `inkMuted` with the word INHERITED) or *overridden* (with the word OVERRIDDEN and a per-value **Reset to inherited**, which removes the override key). A variant can be reset as a whole. Filled-from-default tokens (base missing or outdated theme) show "default" and the reason.
- **Editing a base:** derived themes follow their base. Saving a custom theme that other themes derive from says "*N* themes are based on this one and will change too". Each derived theme offers **Detach (flatten)**: it writes the resolved values as a full theme and drops `base`.
- **Deleting a base:** the dialog lists the dependants and offers "Flatten them first" (default) or "Delete anyway" (they then resolve as base missing).
- **Built-in updates:** a new app version that changes a built-in's values, or adds tokens, flows to every theme derived from it. This is a feature (fixes and new effect colours arrive without the player doing anything) and a risk (a colour the player relied on can change, and an advisory that passed can start failing). On the first launch after such an update, the theme list says which built-in changed and which themes follow it, and the advisories run again. A player who wants fixed values flattens the theme.
- **Storage:** only overrides are stored, so a small change costs a few hundred bytes instead of a full copy, and a fix to the base reaches every derived theme.

### The player's setting

The setting is `{ themeId, variant, documentMode, updatedAt }` (Proposed, open: [T3](09-open-decisions.md#t3)).

**Theme selector (layout Proposed, open: [T7 e](09-open-decisions.md#t7)).** The selector lists **System** first, then Phosphor, Manila and Night Desk, then the client's custom themes by name. System follows the OS brightness live: dark gives Night Desk and light gives Manila, and a change of OS brightness while the app runs switches the theme. The variant drop-down still applies under System. The first-launch default is System with variant `normal`, and a player returns to this behaviour at any time by choosing System. The brightness comes from the platform through Flutter `MediaQuery` [U]. The labels are open ([T7 e](09-open-decisions.md#t7)).

Resolution, in order (Proposed, open: [T3](09-open-decisions.md#t3)):

1. If `themeId` is `system`, take Night Desk or Manila from the current OS brightness. Otherwise find `themeId` among the built-ins and the client's custom themes. If it is missing (deleted, or failed validation on load), render System and say so on the settings screen. The stored setting is not overwritten, so a later import can restore it.
2. If the theme provides `variant` (its own variants, or for a derived theme the variants of its base chain plus the keys in `overrides`; with a missing base, see [Chain checks](#chain-checks-proposed-open-t3)), use it. Otherwise render `normal`, and the drop-down shows the note "*Variant* is not available in this theme; using Normal". The stored `variant` is kept, so a Red-green safe choice comes back when the player returns to a theme that has it.
3. Resolve the tokens as in [Resolving a theme](#resolving-a-theme-proposed-open-t3), so widgets never see a missing token.

### Where it is stored

- **Every account, every client (client-side reading of T2; sync open: [T2](09-open-decisions.md#t2)):** the setting and the custom themes live in the client's small account/cache database (`sembast_web` on the web player), anonymous (tier 0) and full accounts alike. Nothing is written to Firestore or RTDB, so no rule, field whitelist or document cap is involved and `agents/{uid}` is untouched ([12](12-firestore-collections.md#agentsuid-private)). Play works offline. On the web player the data is expected to be lost when the browser's site storage is cleared [U]; on native it goes with the app's data. Export is the backup and the way to move themes to another client.
- **Cross-client sync (open: [T2](09-open-decisions.md#t2)):** whether it is wanted at all in v1. Proposed: local storage per client plus export and import in v1, optional sync later. If sync is added: a separate owner-only document (`appearance/{uid}`, deferred in [12](12-firestore-collections.md#collections-at-a-glance)), never `agents/{uid}`, whose `keys().hasOnly` whitelist stays; a derived theme would sync together with its custom bases.
- **Privacy, kept for the case that sync is added:** a synced colour-blind variant could reveal a real person's vision condition, which is outside [11](11-supplemental-features.md#real-personal-data)'s real-personal-data list and its consent scope. If sync is added, the variant is stored as a neutral rendering label (`variant`) with no health framing anywhere in the data or the UI, owner-only, never public, never indexed, never visible to the GM and never used for anything but rendering (the variant could instead stay local-only, or 11 could be amended). With storage on the client only, nothing leaves the device.

### Custom themes (Proposed, open: T3)

- **Create** by duplicating or deriving from a built-in or another custom theme ([Derived themes](#derived-themes-base-and-overrides-proposed-open-t3)).
- **Edit** every token in every variant the custom theme provides, including the window edge, document and effect tokens. The player can remove variants other than `normal`. Input is hex entry with a swatch (with an alpha field only for alpha-capable tokens), plus the source theme's own colours as quick picks. A colour-picker package would need approval (CLAUDE.md §6).
- **Live preview:** a pane renders a sample window with its edge, a record table, all six chips with glyphs and words, a lock card, a highlighted field, an intrusion ground and a scene tint sample, a paper document (in the theme and in document mode), line status, marks, supervisor and anomaly, using the resolved map being edited. Nothing changes outside the pane until Save.
- **Advisories, never blocking.** The editor runs the study's checks, with the same methods and thresholds: WCAG 2.x contrast (4.5:1 for text, 3:1 for large text, UI parts and a chip against `window`), and CIEDE2000 differences after the Machado et al. (2009) severity 1.0 simulation in linear RGB (result chips 15 apart in normal, protan, deutan and tritan vision; 18 from chrome fills, `anomaly` and `supervisor` in normal vision only, rule d; `confirm` and Warning and Locked 15 from the result chips). Achromatopsia is checked only in `highContrast`. Each failing pair shows a warning next to the token and in a summary, together with any effect-safety substitutions. The player can still save and apply.
- **Reset cannot be lost.** The appearance settings and the editor draw their own chrome in the custom theme's fallback built-in ([Fallback built-in](#fallback-built-in-proposed-open-t3)); only the preview pane uses the custom colours. Applying a custom theme asks for confirmation and reverts after 15 seconds without an answer. "Reset to System" (which selects System, the first-launch default) stays on the settings screen and in the app menu, reachable by keyboard. A bad custom theme therefore cannot hide the way back.

### Documents and document mode (Proposed, open: T6)

- **Documents follow the theme.** Bureau forms, handouts and other paper documents (§10 Forms and filing) render with the document tokens of the resolved theme. In the built-ins these are the same in every theme and variant (§6.1: paper is a fiction object), so the built-ins look as the design shows; custom themes may change them. The four document tokens `paperInkMuted`, `paperRule`, `paperStamp` and `paperRedact` are Proposed (open: [T6](09-open-decisions.md#t6)) and cover what the forms need beyond §6.1: `paperInkMuted` (margin text such as the vertical "Form Approved." line, time stamps), `paperRule` (fill lines, table rules and the header rules), `paperStamp` (stamps and the classification line, single ink colour) and `paperRedact` (redaction bars on paper). Proposed built-in values, from §6.1 ladder steps whose contrast on beige tint 45 is already computed there: `paperInkMuted` `#5F5348` (5.57:1), `paperRule` `#7E6E5F` (3.66:1), `paperStamp` `#A8382B` (as `paperAlert`, 4.81:1), `paperRedact` `#050505` (Manila's `redact`). The seal keeps its own colours in every theme and mode (§6.7); it is artwork, not tokens.
- **Document mode (Proposed, open: [T6](09-open-decisions.md#t6)).** Every view that displays a document has a **Document mode** toggle (a checkbox or button in its title bar; label wording open: [T7 e](09-open-decisions.md#t7)), in every theme and variant. It switches that document to the **standard paper set**: the built-in document token values above, fixed, not themeable, not stored in any theme document and not affected by the effect-safety rule because it already passes. Chip outlines on paper stay `paperInk`. The toggle acts per view; the setting's `documentMode` is the remembered preference applied when a document opens (default off). Changing the toggle in a view does not change the preference unless the player ticks "Remember for all documents".
- **Print and export defaults (Proposed).** Printing or exporting a document always uses the standard paper set, never the custom theme (open: [T10](09-open-decisions.md#t10)). The design review's DEC-29 proposes black on white for print by default with the paper tint as an option; which one is the default is open ([T10](09-open-decisions.md#t10)).
- **Renderer (open: [T10](09-open-decisions.md#t10)).** Documents will eventually be rendered by an in-house pipeline (typst or another solution). The choice of renderer is open: any new dependency or tool needs approval first (CLAUDE.md §6). The synthesis §10 Forms and filing (§10.6 Print and export) has the related ideas. Until then document views are Flutter widgets drawn from the tokens.

### Import and export (Proposed, open: T3)

- **Export** writes one theme as a JSON file in the schema above. **By default the file is flattened**: every variant the theme provides with all 42 values resolved, no `base`, the build's current `tokenSet`, so the file stands alone on any client. The option **Export as overrides only** writes `base` and `overrides` as stored; the file then needs its base installed on the receiving client, and the export dialog says so. Built-ins can be exported too, as a starting point. The web player uses a browser download. Native builds use a save dialog. The file-dialog package (picker and save) is not chosen here; it needs approval before implementation (CLAUDE.md §6).
- **Import** reads a file through a file picker (on the web, the browser's). Invalid themes are rejected. It validates the file in this order (Proposed, open: [T3](09-open-decisions.md#t3)), and it reports every problem at once with its JSON path, as the pack loader does:
  1. Size at most the parser safeguard ([Technical safeguards](#technical-safeguards-proposed-open-t3)) before parsing; must be valid JSON.
  2. `format` is `bard-theme`; `schemaVersion` and `tokenSet` (and `base.tokenSet`) are versions this build knows. A newer one is rejected with "made by a newer version; update the app".
  3. Only the fields above are allowed. Unknown fields, unknown variant keys and unknown tokens are errors. Exactly one form: `variants` (with `normal`, every variant holding every token of the file's `tokenSet`) or `base` plus `overrides` (any subset of known tokens; `base.id` a non-empty string).
  4. Every colour matches `#RRGGBB`, or `#RRGGBBAA` for an alpha-capable token (any case; stored upper case). Anything else is rejected, never clamped or guessed, so a file never shows colours other than the ones it contains.
  5. `name` is trimmed, control and bidirectional-override characters are removed, it must not be empty, and it is always displayed as plain text, never as markup or a link.
- **After validation (not errors):** a derived file whose base is not installed is imported and flagged as in [Chain checks](#chain-checks-proposed-open-t3), with **Flatten** offered. A full theme on an older `tokenSet` is imported and flagged as in [Outdated themes](#outdated-themes-proposed-open-t4), with **Add missing colours** offered. The advisory checks run on the imported theme.
- **Ids:** an import keeps the file's id when no theme on this client has it, so overrides-only files from the same author still find their base. If the id is taken by a custom theme, the player chooses **Replace** (updates it in place; its derived themes follow) or **Keep both** (new id; the name gets a suffix, " (2)"). Before a Replace, the cycle check runs on the incoming document's base chain against the installed themes; if replacing would create a loop, Replace is refused with the loop named, and Keep both or Flatten is offered. A built-in id is never replaced: the import gets a new id.
- **Data only.** The schema has no field for a URL, script, asset path, image or font, and unknown fields are rejected, so importing never fetches or runs anything.
- **Sharing:** players share themes outside the app, as exported files. No in-app gallery, upload or moderation queue in v1 (Proposed, open: [T5](09-open-decisions.md#t5)), so no public content is involved ([11](11-supplemental-features.md#library-and-public-content)).

### Technical safeguards (Proposed, open: T3)

There are no limits on player theming. These safeguards are not theming limits: they only stop corrupt or hostile data from hanging the parser or the resolver. Both values are Proposed (open: [T3](09-open-decisions.md#t3)).

| Safeguard | Proposed | Why |
|---|---|---|
| Import file size | 1 MiB, checked before parsing | Over 200 times a flattened four-variant theme; only a file that is not a theme reaches it |
| Base chain depth | 32 links | Far beyond any hand-made chain; stops a corrupt chain from looping the resolver (cycles are caught separately) |

No cap on the number of custom themes, name length, overrides or variants.

### Layering

The theme model is a separate package so that it can grow after v1 without touching `ui_kit` or the engine. The package name `theme_core` is Proposed (open: [T11](09-open-decisions.md#t11)), in line with `content_core`.

- **`theme_core`** (pure Dart, Dart SDK only, no Flutter import): the theme document model (`ThemeDocument`, `ThemeVariant`, colour values), the hand-written JSON codec and validator, the token registry with token sets, alpha capability and the version map, the resolver (fallback built-in, lookup, chain checks, outdated fill, effect-safety pairs), the colour math (WCAG contrast, CIEDE2000, and the Machado et al. CVD simulation, shared by the editor advisories and the tests), the standard paper set, and the built-in theme JSON files under `assets/themes/`.
- **How the built-ins ship (Proposed, open: [S-4](09-open-decisions.md#s-4-how-the-built-in-theme-json-ships)):** as JSON assets in `theme_core`, declared in its pubspec's `flutter: assets:` section the same way `content_core` declares its pack today (state of our code, `packages/content_core/pubspec.yaml`, a package without a Flutter dependency). `ui_kit` loads them through the Flutter asset bundle and passes the strings to `theme_core`'s codec, so `theme_core` never imports Flutter; `theme_core`'s own tests read the files directly. The JSON stays the single source D edits (CLAUDE.md §9), the same validator checks built-ins and imports, and nothing is generated.
- **`ui_kit`** (Flutter and `signals_flutter`, plus `theme_core`): the asset loader for the built-ins (Proposed, open: [S-4](09-open-decisions.md#s-4-how-the-built-in-theme-json-ships)), the settings, selector, editor and document-mode widgets, and a `ThemeController` that exposes the resolved tokens as a signal, follows the OS brightness for System, and maps the tokens to Flutter `ThemeData` plus a theme extension for the custom tokens [U].
- **Apps:** an `AppearanceRepository` in `data/repositories` over the local store only (no backend gateway in v1), built in `composition.dart`, using `theme_core`'s codec to store and load theme documents. View models read and write through it (layering above; CLAUDE.md §8). The companion app uses the same pieces.
- **Dependency rules:** [00](00-overview.md#dependency-rules) gains `theme_core ──► (Dart SDK only)`, and `ui_kit` and the apps may import it. When the package is built, the pub workspace member list and the layer table in `tool/lib/dependency_rules.dart` (checked by `tool/bin/check_dependency_rules.dart`) are updated in the same change.
- **Extension room (not designed):** theme distribution, per-campaign theme settings, and custom icons, images and animations are possible additions after v1. None of them is designed here; the separate package gives them a place.
- **Engine, protocol and session are untouched.** Appearance is presentation only: it is never a command or event, never in the event log or text log, and never sent to other participants. Handler-forced effects (lock cards, highlights, intrusion cues) come from their own features' events, designed with those features; they only name effect tokens and never carry a colour or a theme. Theme settings are never a gateable shell capability for the GM (Proposed, open: [S-9](09-open-decisions.md#s-9-gateable-shell-capabilities)).
- **Web player:** the web player gets the whole feature (settings, custom themes, derived themes, document mode, import and export). Nothing here is hosting, so no capability gate applies.

### Accessibility, and what is not guaranteed

- The built-in variants pass the study's hard rules a to e (`colorblind-palettes.md` §1, §2.4). Achromatopsia separation is required of `highContrast` only. Warning falls below 15 dE from the result chips in three built-in sets (Manila Default, Manila Blue-yellow safe, Night Desk High contrast); there the glyph and word carry it. The four new effect tokens are not yet computed (open: [T4](09-open-decisions.md#t4)); `windowEdge` is checked for contrast only.
- The figures come from a simulation, not from people. Testing with colour-blind users is owed: VER-14, defined in the project library's design review (`design/review-list-for-R.md`) and recorded in [09](09-open-decisions.md#still-unproven). Values may change after it.
- Custom and imported themes are not guaranteed accessible. The advisories inform the player and do not block. The one exception is the effect-safety rule: forced effects and documents are always readable.
- Not covered: OS forced-colours and high-contrast modes, and colour shifts from texture, anti-aliasing and display calibration (study §6). Print uses the standard paper set. Text size, reduced motion and the signal texture are separate settings (§6.3, §6.5, §6.6), not part of a theme.
- "High contrast" here is the study's result-chip set; it does not raise the chrome's contrast.

### Tests to write

- **Unit, codec and validator (`theme_core`):** a round trip for each built-in and for a derived theme; one failing case per error class (oversize, bad JSON, wrong `format`, unknown `schemaVersion`, newer `tokenSet`, unknown field, both forms or neither, missing `normal` in a full theme, a full theme missing a token of its own `tokenSet`, unknown token, empty `base.id`, non-hex and 3-digit colours, alpha on a token that is not alpha-capable, empty or control-character `name`), each with its JSON path; every problem reported in one pass; a URL or script string in an unknown field is rejected as an unknown field; a sparse `overrides` map is valid; `#RRGGBBAA` on `sceneTint` and `highlight` is valid and round-trips unchanged.
- **Unit, token registry:** every token of every set has a built-in value in every variant of every built-in; `windowEdge` matches the table above and meets 3:1 against `desk`, `window` and `windowRaised` in all 12 sets.
- **Unit, resolution chain:** own value, then base, then base's base, then the fallback built-in's variant, then its `normal`; a theme derived from Phosphor and a duplicate of Phosphor (`copiedFrom`) fall back to Phosphor; only a theme with no built-in in its chain or `copiedFrom` uses `brightness`; an override for a variant the base lacks; a base edit changes the derived result; flattening gives the same resolved map as the derived theme.
- **Unit, chain checks:** a two-theme and a self-referencing cycle are detected, every member is flagged and resolves as base missing; the editor refuses a cyclic base; an import Replace that would close a loop is refused; a chain past the depth safeguard is flagged; a missing base falls back, keeps the overrides and lists the fallback's variants flagged; installing the base restores the look.
- **Unit, outdated themes and effect safety:** a full theme on an older `tokenSet` gets exactly the newer tokens from the fallback built-in and is flagged with the version from the registry; a derived theme whose base supplies every token is not flagged; **Add missing colours** copies only still-missing tokens and never base-supplied ones; a custom pair from each row of the effect-safety table that fails its minimum (for example `onLocked` equal to `locked`, `inkMuted` equal to `window`, `paperInk` equal to `paper`) is replaced inside that element by the fallback built-in's value while the token keeps the player's value elsewhere; a Phosphor-derived theme with a failing `anomaly` gets Phosphor's `anomaly`, not Night Desk's; a failing custom surface makes the element draw the fallback surface; passing custom pairs are left alone; alpha-capable tokens are checked composited.
- **Unit, setting:** System picks Night Desk or Manila from the OS brightness and follows a change live; first launch stores System; missing theme renders System and keeps the stored setting; missing variant gives `normal` and keeps the stored variant; switching back restores the variant.
- **Unit, colour math:** contrast reproduces the palette-card figures (`#04650D` against white 7.31, `#DCBFA6` against black 12.05, `#0072B2` against white 5.19); CIEDE2000 matches the published Sharma, Wu and Dalal (2005) test pairs; simulated differences reproduce the study's tables (for example Phosphor Default success-partial 52.0 under deuteranopia); the advisories on the built-ins are exactly the study's known exceptions and nothing else.
- **Unit, repository:** with a fake local store, nothing is written to the backend for any account; import keeps a free id, asks on a taken custom id and never replaces a built-in; deleting a base with "Flatten them first" leaves the dependants' resolved maps unchanged.
- **Widget:** the selector lists System, the three built-ins and custom themes by name; the variant drop-down lists only what the theme provides, and an unavailable stored variant shows the note; the editor marks inherited and overridden values and **Reset to inherited** removes the override; editing a token updates only the preview until Save; a failing advisory shows and Save stays enabled; the outdated and base-missing notices show in the list and the editor; settings chrome stays readable under a deliberately unreadable custom theme; the timed revert fires; Reset is reachable by keyboard; every chip shows glyph and word in every built-in variant and in a custom theme; a lock card and a highlight stay readable under an unreadable custom theme; with effects off, a scene tint is replaced by its static notice while a lock card still shows.
- **Widget, document mode:** the toggle is present on every document view in every theme and variant; it switches that view to the standard paper set and back; the remembered preference applies to a newly opened document; print and export use the standard set whatever the theme.

### Open items

The open theme items ([T2](09-open-decisions.md#t2), [T3](09-open-decisions.md#t3), [T4](09-open-decisions.md#t4), [T6](09-open-decisions.md#t6), [T10](09-open-decisions.md#t10), [T11](09-open-decisions.md#t11)) are in [09](09-open-decisions.md#open-for-r-themes); [T5](09-open-decisions.md#t5) and [T7 e](09-open-decisions.md#t7) are under [Pending D](09-open-decisions.md#pending-d).

## Platform rules

- No `dart:io` imports in shared code; platform-specific services use conditional imports keyed on `dart.library.io` / `dart.library.js_interop` [V-12].
- No `Platform.isX` checks in shared code; they throw on the web [V-12].
- Hosting capabilities differ by platform (the web build cannot host, see [04-session.md](04-session.md#play-modes)). The UI asks the session which transports are available instead of checking the platform itself.

- Desktop builds reach Firebase through `firebase_dart` (planned; not built, 10 §5): probed on Windows and Linux, the v1 desktop targets ([06-accounts-backend.md](06-accounts-backend.md#stack)). Push notifications are in-app only on Windows and Linux.
- **Windows identity (planned; see [06 Auth token storage](06-accounts-backend.md#auth-token-storage)).** The Windows runner's company and product names decide where `flutter_secure_storage` keeps the auth-box key (`%APPDATA%\<company>\<product>\`) [V-44]. They are set once before the first release and not changed, or every user is signed out.

### Web build role

The web build is a lightweight, player-only client that reaches people who have not yet decided to install the app. There is no GM hosting on the web. A GM on the web would lose control over engine version, pack choice and modifying their own games, features most GMs would want; those live in native builds. Features are gated by a capability set the app reads at startup (for example `canHost`, `canEditPacks`; planned, 10 §5), so a later change is a configuration change, not a restructure.

## Planned screens

Proposed screens that follow from the game rules; none is built.

- **Death screen.** A character reaching 0 Health flashes a death screen. Proposed (open: [FD-D4](10-waiting-on-d.md#fd-d4)): show it to the player who lost the character and the Handler, with the other players seeing a line in the log.
- **Handler effect list.** The Handler picks the DC and the effect from a list of one-click effects built on the engine's consequence events, plus a custom text option (the list contents are open: [FD-D2](10-waiting-on-d.md#fd-d2)). The sanity review tray shows the book's ranges as suggestions.
- **Cast DC helper.** The Handler types the final DC; a labelled factor list is Proposed (open: [FD-M3](10-waiting-on-d.md#fd-m3)).
- **Roster shows personas.** Inside an operation the roster shows the Handler persona, never the GM account.
- **Personal library.** A per-account view over archived documents the player wrote or is mentioned in; a read-only index in Firestore pointing at archived items, with no new storage of the content. The document kinds are open ([FE-L5](10-waiting-on-d.md#fe-l5), [10](10-waiting-on-d.md#1-unanswered-questions-for-d)).
- **Name reveals.** The player log renders names from what that viewer knows ([04](04-session.md#names-in-the-log)).

## The app shell never affects outcomes

Concretely: no numeric rule, table or formula lives in `apps/`. Code review rejects any arithmetic on game values in a view model except formatting. Read models in the engine provide every derived number the UI shows.
