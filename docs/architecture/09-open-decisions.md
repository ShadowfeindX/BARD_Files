# 09. Open decisions

This chapter lists what is still open: items waiting on D, items waiting on R, items held for a probe, deferred concerns, known issues and unproven claims. Decided items are not listed here; each chapter states its rulings as design and cites the ruling's id (P10c, F2, R-A1 and so on) as a plain tag. The record of rulings (id, date, rationale) is [decision-record.md](decision-record.md).

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
