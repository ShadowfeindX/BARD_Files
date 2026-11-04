# 09. Open decisions

This chapter lists what is still open: items waiting on D, items waiting on R, open spec proposals, items held for a probe, deferred concerns, known issues and unproven claims. Decided items are not listed here; each chapter states its rulings as design only; ids, dates and reasons are in the record. The record of rulings (id, date, rationale) is [decision-record.md](decision-record.md).

D's open game-content and design questions, with their options and defaults, are in [10-waiting-on-d.md](10-waiting-on-d.md); R's open items from the same meetings are there too.

## Pending D

Still waiting on D and on R for the game-content and design items: see [10-waiting-on-d.md](10-waiting-on-d.md). The rows below are the platform and theme items.

| Item | What is undecided | Already fixed |
|---|---|---|
| T5 theme sharing (owner R and D; next R and D meeting) | Whether themes are shared only externally as exported files in v1, as R expects, or also in the app (a gallery would go through moderation, [11](11-supplemental-features.md#library-and-public-content)). Added 2026-11-04 (T9). | Proposed: no in-app gallery, upload or moderation in v1. |
| T7 (e) theme labels (owner D; next R and D meeting) | D confirms the variant labels (Normal, High contrast, Red-green safe, Blue-yellow safe) and the System label in the theme selector; Proposed: the document mode label goes with them. Added 2026-11-04 (T7). | The variants and the System behaviour (T1, T7 d). |
| DEC-41 map geometry (owner D; next R and D meeting) | Whether maps get any geometry rules: cover, terrain, line of sight, facing, areas. The rulebook has none. Numbered in the project library's design review (`design/synthesis-government-terminal.md`). | Until D rules, a map is style only and carries no rule effect (design, Proposed). |

## Open for R (themes)

Proposed in [07](07-apps.md#themes-and-player-appearance-settings), not ruled. These are what is left after T1, T7, T8 and T9; T5 and the T7 (e) labels are under [Pending D](#pending-d). Nothing built depends on them.

| Item | What is undecided | Proposed | Owner |
|---|---|---|---|
| T2 sync | Whether cross-client sync of the setting and custom themes is wanted at all in v1; whether "only for the player client" excludes the Handler console. | Local storage per client plus export and import in v1; optional sync later. If sync is added: owner-only `appearance/{uid}` (deferred in [12](12-firestore-collections.md#collections-at-a-glance)), never `agents/{uid}`, whose `keys().hasOnly` whitelist stays; the variant as a neutral rendering label with no health framing, because a synced colour-blind variant sits outside 11's real-personal-data list (alternatives then: variant local-only, or amend 11). | R |
| T3 safeguards and derived themes | Technical safeguards that are not theming limits; the base-and-overrides design. | Import file ceiling 1 MiB before parsing and base chain depth 32 (R can veto either); `base` (id plus token-set version) and sparse per-variant `overrides`; lookup own value, base chain, the fallback built-in (chain root, else `copiedFrom`, else brightness) for the variant, then its `normal`; cycle detection flags every member of a loop; missing base falls back with a notice and **Flatten**; export flattened by default, "overrides only" as an option; derived themes follow base edits and built-in updates (a feature and a risk), with **Detach (flatten)**. | R |
| T4 effect tokens | New effect and highlight token names and values; the outdated-theme solution; the effect-safety rule; player opt-out. | Existing design tokens for lock cards and cues (`locked`/`onLocked`, `warning`/`onWarning`, `anomaly`, `supervisor`, `rule`, `ink`, `inkMuted`); new `highlight`, `intrusionGround`, `onIntrusionGround`, `sceneTint`, initially reusing existing tokens until computed by the study's method; token sets with a version map; only tokens no theme in the chain supplies are filled from the fallback built-in, with a notice and **Add missing colours**; failing effect and document pairs use the fallback value inside that element only; the player's effects opt-out wins (DEC-16 A). | R |
| T6 document tokens and document mode | New document token names and values; document mode. | New `paperInkMuted`, `paperRule`, `paperStamp`, `paperRedact` from §6.1 ladder steps; a Document mode toggle on every document view (per view plus a remembered preference) showing a fixed, non-themeable standard paper set, also used for print and export. | R |
| T10 document renderer | The pipeline that renders documents (typst or another solution; no new dependency or tool without R's approval, CLAUDE.md §6); the print default. Related ideas: the synthesis "Forms and filing" section (print and export), cited by name. | Not chosen. Print and export use the standard paper set; DEC-29's black on white is the alternative print default. | R |
| T11 T7 follow-ups | The `windowEdge` values; the `theme_core` name. | `windowEdge` Phosphor `#C0D8C2`, Manila `#5F5348`, Night Desk `#B8D8E9` in all four variants (at least 3:1 against `desk`, `window` and `windowRaised`, computed from the design library's §6.1 values); package name `theme_core`. | R |

## Open spec items

Proposals written into the chapters as structured designs, not yet ruled. Each has a stable id; the chapter that describes the proposal links here. Nothing built depends on them. Owner is the one who rules.

### O-03-1 Protocol message bodies

- **Undecided:** the field names of the message bodies (`hello`, `welcome`, `refused`, `request`, `rejected`, `events`, `resync`, `textlog`, `presence`, `ping`/`pong`), the refusal reason `anonymousAliasLimit`, and the engine version format (SemVer `major.minor.patch` with optional pre-release; no build metadata or leading zeros).
- **Options:** one proposal, as written in the chapter. These are the only wire details the spec left open.
- **Owner:** R. **Described in:** [03](03-protocol.md#message-bodies).

### O-05-1 Notice after migration

- **Undecided:** the notice players see in the log after a migration, saying that history before it is archived text.
- **Options:** one proposal: players do nothing and see the notice in the log.
- **Owner:** R. **Described in:** [05](05-migrator.md#gm-workflow).

### O-08-1 Continuous integration job list

- **Undecided:** the CI job list: format, analyze, tests, dependency-rule check (including the transitive check), pack validation and the pinned-package check.
- **Options:** one proposal, as written in the chapter.
- **Owner:** R. **Described in:** [08](08-testing.md#continuous-integration-proposed).

### 06-O1 Firestore REST client token handling

- **Undecided:** how the REST client handles token refresh and index or claim errors.
- **Options:** proposed: call `getIdToken()` for every request and never cache the token string; on 401 retry once with `getIdToken(true)`; surface `FAILED_PRECONDITION` as a missing-index error; force `getIdToken(true)` after a role change.
- **Owner:** R. **Described in:** [06](06-accounts-backend.md#firestore).

### 06-O2 Anonymous-to-full account upgrade

- **Undecided:** the upgrade path, and whether hosting requires a verified email (the upgraded account has `email_verified: false`).
- **Options:** proposed path: `updateEmail` then `updatePassword` on the signed-in `firebase_dart` user (keeps the uid), then `getIdToken(true)`; the Identity Toolkit `accounts:update` route is not used. The verified-email requirement is undecided.
- **Owner:** R. **Described in:** [06](06-accounts-backend.md#account-model).

### 06-O3 Claim pickup after a role change

- **Undecided:** how a client picks up a changed claim.
- **Options:** proposed: the roles function writes an inbox notice to `/inbox/$uid`; the client calls `getIdToken(true)` and reloads `Entitlements`. Untested whether a client without the notice picks the claim up when its token expires.
- **Owner:** R. **Described in:** [06](06-accounts-backend.md#roles).

### 06-O4 Where the phone-box clear-up runs

- **Undecided:** where the phone-box clear-up runs.
- **Options:** proposed: it moves from episode archive to the operation-end step (a function clears the box with admin REST); until built, the box stays with the locked stub.
- **Owner:** R. **Described in:** [06](06-accounts-backend.md#realtime-database-model-live-play).

### S-1 Event entry wrapper

- **Undecided:** the wrapper for event entries: full, redacted and hidden entries per recipient, the JSON shapes, the `req` acknowledgement and resync on a gap.
- **Options:** hidden entries for events a recipient cannot see (chosen in the proposal, so `seq` stays consecutive); or per-recipient gaps, which would break the consecutive-`seq` rule.
- **Owner:** R. **Described in:** [04](04-session.md#event-entries); also referenced from [03](03-protocol.md).

### S-2 `SendPhoneMessage` names and fields

- **Undecided:** the command and field names of `SendPhoneMessage(from, to, text)`. The behaviour (party rules, 1 to 2,000 UTF-16 units) is design.
- **Options:** names and fields as proposed in the chapter.
- **Owner:** R (an engine row, see the Proposed rows in [01](01-engine.md#planned-code-changes)). **Described in:** [04](04-session.md#in-game-phone).

### S-3 Perspective-panel feature areas

- **Undecided:** the grouping of feature areas (Episode console, Dossier, World, Phone, Library, Filing); the content of each is to be set by R.
- **Options:** the grouping as proposed in the chapter.
- **Owner:** R. **Described in:** [07](07-apps.md#perspective-panels).

### S-4 How the built-in theme JSON ships

- **Undecided:** how the built-in theme JSON ships and where `ThemeController` lives.
- **Options:** recommended: JSON assets in `theme_core`, declared in its pubspec, loaded by `ui_kit` and passed to the codec. Alternative: generated Dart constants (no asset loading in the package, but a generation step that CLAUDE.md section 10 asks to avoid or document, and rules-like data in code). The controller lives in `ui_kit` as proposed; if R prefers, it lives in each app.
- **Owner:** R. **Described in:** [07](07-apps.md#layering).

### DEC-07 Intrusion cues

- **Undecided:** whether and how intrusion cues happen (id from the project library's design review). The theme chapter only says which colours such effects may use (T4).
- **Options:** none written.
- **Owner:** R and D. **Described in:** [07](07-apps.md#effect-and-highlight-tokens).

### DEC-34 and GAP-33 Capability lock cards

- **Undecided:** which capability-lock-card effects exist (library synthesis section 12, revision 4).
- **Options:** none written.
- **Owner:** R. **Described in:** [07](07-apps.md#effect-and-highlight-tokens).

## Known issues and follow-ups

Not decisions; work still owed. T11 is under [Open for R (themes)](#open-for-r-themes).

- **No web target.** `apps/bard` has `linux/` and `windows/` folders but no `web/`, so the player-only web build in the v1 platforms does not exist yet.
- **No Chrome widget tests.** CI runs the `engine` and `session` tests on Node.js as well as the VM. Nothing runs on Chrome, so `ui_kit` and `apps/bard` widget tests are unproven on the web.
- **`check_all.sh` fails in a checkout with untracked Dart files.** Its `dart format .` step covers the whole folder, including untracked ones such as local probes. A clean clone passes on its first run (checked on Windows, 2026-11-04).
- **Session gaps.** `docs/developer-guide/session.md` lists the known gaps in the session layer.

## Held

| Item | Waits on |
|---|---|
| P10c Firestore collections | Drafted (Proposed), awaiting R: [12-firestore-collections.md](12-firestore-collections.md). Rules and indexes not yet run in the Emulator Suite. |

## Deferred

- **Concern 6, payments.** No provider, product or entitlement model is decided. The `Entitlements` read model and placeholder webhook/receipt functions stay; probe 8.8 (provider and app-store policy) runs when R wants monetization designed, likely with D.

## Still unproven

- FS2 on Windows for natural expiry, plus revoked sessions, disabled users, password change and refresh-token failure (Linux natural expiry, composite indexes and claim rules: done [V-43][V-45]).
- FS3: the RTDB role from a deployed function running as its dedicated service account (tested by impersonation only) [V-46].
- 8.4 claim pickup on Windows (Linux done [V-42]).
- RTDB rules on a deployed database with real signed tokens, and custom claims in RTDB rules (emulator only so far [V-38]).
- Opening an existing plaintext `firebase_auth` box with the cipher (the B5 migration step) [V-34][V-44].
- **VER-14 (themes, T1; defined in the project library's design review, recorded here as the repo's entry):** the built-in theme variants (the 12 sets in the library's `design/colorblind-palettes.md`), and the confirm, Warning and Locked colours are tested with real colour-blind players (at least protan, deutan and tritan viewers and one low-vision viewer) on the target displays. Testers to be chosen by R and D; values are revised if the test disagrees with the simulation. Proposed extension, not in the library's entry: include the `windowEdge`, effect and document colours once their values are set (T4, T6, T11).
- Deep links on Wayland, Flatpak, Snap and packaged builds [V-30]. macOS and iOS are not in v1 (R, 2026-10-20), so their checks are dropped.
