# 09. Decisions record and open items

R reviewed this spec item by item on 2026-10-20. This chapter records each ruling, then lists what is still open: items waiting on D (creative director), items held for a probe, and deferred concerns. The other chapters state the rulings as design; this chapter is the index.

Package versions below were re-checked on 2026-10-20 [V-28]–[V-35]. Standing rule (F5): re-verify each package's version and platforms on pub.dev right before it enters a pubspec, and pin exact versions where deterministic behaviour matters (`xrandom`, `sembast`, `hive`).

## Decisions record (ruled by R, 2026-10-20)

Later rulings are added to their group with the date in the row (for example P10c 2026-10-21, T1, T7, T8 and T9 2026-11-04).

### Structure and engine

| # | Ruling | Where |
|---|---|---|
| P1 | Extra packages `content_core`, `backend`, `ui_kit`. | [00](00-overview.md) |
| P2 | Pub workspace monorepo, `packages/` + `apps/`. | [00](00-overview.md) |
| F4 | New SDK-only `protocol_envelope` package (envelope, message types, version negotiation). `protocol` keeps the engine codecs and depends on it. `apps/functions` depends only on `protocol_envelope`, so the engine never enters the functions' dependency graph. Reason (R): no wire-format concerns in the engine. | [00](00-overview.md), [03](03-protocol.md) |
| P4 | Data-only dice expressions and formulas, no scripting. Adds the `var` node `{"type":"var","key":<name>}`, a named number the engine supplies at evaluation time (advancement XP = 10 × `newScore`; assist bonus = 1d6 + `helperSkillBonus`). | [01](01-engine.md), [02](02-rules-packs.md) |
| P5 | RNG from pub package `xrandom` 0.7.2, class `Xoshiro128pp` (one of the generators `xrandom` marks as working on JS), never the `Xrandom`/`Drandom`/`Qrandom` aliases. Adapter behind the engine's `Rng` interface lives in `session`; engine stays SDK-only. Pinned exactly; known-seed test vectors on native and web [V-28]. | [01](01-engine.md), [04](04-session.md) |
| P11 | Deprecation record (`since`, `replacedBy`, `removeIn`, `note`) for engine schema and pack entries. | [01](01-engine.md), [02](02-rules-packs.md) |
| F1 | Rulebook gaps settled: proficiency bonus is an additional dice roll (G16); Health = END × LCK; Sanity = WIS × LCK; top category Cat-Ω, values decided by the Handler (G12); disorder table is a clean 1–6. Only the occult check attribute (C5/G6) stays open, pending D. | [01](01-engine.md), [08](08-testing.md) |
| F2 | GM review gate in `OperationHost`: consequence events (damage, sanity loss, conditions, any category value) are held as a GM-only pending batch; the GM confirms or edits; an edit is recorded on the event (`overriddenFrom`); only then seq, narrate, store and broadcast. Per-operation auto-confirm. Rolls are never gated: `CheckResolved` broadcasts immediately and rolled faces are never altered. Covers rulebook decision 21. | [01](01-engine.md), [04](04-session.md) |
| F3 (2) | Skill = name, description, category (one of five, organizational only), attribute, proficiency. No "allowed uses". | [01](01-engine.md), [02](02-rules-packs.md) |
| F3 (3) | Operation-scoped pack tier under Campaign for per-session GM content: same schema and validator, pinned and logged. | [02](02-rules-packs.md) |
| Concern 7 | `CheckResolved` reserves `source` (`rng` \| `entered`, plus who entered: GM or alias). The physical-dice feature itself is pending D. | [01](01-engine.md) |

### Packs and content

| # | Ruling | Where |
|---|---|---|
| P3 | Packs are JSON + manifest (not YAML); UI editing is planned since GMs publish packs too. The exact pack shape is pending D. | [02](02-rules-packs.md) |
| Packs | Authoring annotations (`note`, `source`, `openItems`, `placeholder`, `gap`, `*Note` keys) are stripped before shipping; no reserved annotation key, so unknown keys stay errors in shipped packs. | [02](02-rules-packs.md) |
| Concern 5 | Library verification claim held by R and D only at first (set by the roles function; more auditors later through the console). Revocable: the item returns to pending with a reason; copies already in GM packs are unchanged. The item records verifier, date and version. | [02](02-rules-packs.md), [06](06-accounts-backend.md) |

### Protocol, session and migrator

| # | Ruling | Where |
|---|---|---|
| P6 | Hand-written `toJson`/`fromJson` codecs with `dart:convert`; no `build_runner`. | [03](03-protocol.md) |
| P7 | Actors are single-threaded mailbox objects, not isolates. If UI lag appears it is solved another way. | [04](04-session.md) |
| P12 | Text log narrated during play (after the GM confirms a consequence batch), one variant per perspective; `textlog` message; genesis `archives`; new op id with seq restart. Rolling autosave: native hosts write events, text and head snapshot to the local store every batch, followed by a commit marker in its own transaction; on open, everything after the last marker is discarded [V-31]. The head snapshot is mirrored to RTDB on a GM-configurable per-operation interval (proposed default 5 minutes, plus on pause, close and before migration); event and text batches go to RTDB every batch. No power-loss protection in v1 (accepted). | [01](01-engine.md), [04](04-session.md), [05](05-migrator.md), [06](06-accounts-backend.md) |
| 09-4 | Transport build order: in-process, LAN, RTDB relay, P2P. Transport packages (`web_socket_channel`, `bonsoir`, `flutter_webrtc`) are not approved yet; each goes to R when its transport is scheduled. | [04](04-session.md) |
| Targets | v1 targets (R, 2026-10-20): Windows and Linux desktop, plus the web player build. macOS and iOS are not in v1, and their pending checks are dropped. | [00](00-overview.md), [07](07-apps.md) |
| W1 | Web build is player-only for now (no GM hosting). Revisit with D. | [04](04-session.md), [07](07-apps.md) |
| P8 | Migrator works on frozen JSON-level schemas; steps are pure `(json, decisions) -> (json, report)`. | [05](05-migrator.md) |
| P13 | Migration confirmation on a separate warning screen: tick "cannot be recovered" and type the operation name; a single tap never confirms. | [05](05-migrator.md) |

### Apps

| # | Ruling | Where |
|---|---|---|
| 09-1 | State management: `signals_flutter` 7.1.0 (Dart Signals, publisher rodydavis.com) in apps and `ui_kit`, not the umbrella `signals` package [V-29]. | [07](07-apps.md) |
| 09-2 | Routing: `go_router` 18.1.1 with `app_links` 7.2.2 for desktop link delivery. Canonical join link `bard://join/<op>?alias=<id>`; https links later where supported. Verified live on Linux and Windows [V-30]; macOS and iOS are not in v1. | [07](07-apps.md) |
| 09-3 | Persistence: `sembast` 3.9.0 (+ `sembast_web` 2.4.6+1 for web player caches) behind `EventStore`, one database file per operation opened on demand plus a small account/cache database [V-31]. | [04](04-session.md), [07](07-apps.md) |
| T1 | Themes and appearance, ruled by R 2026-11-04: theme choice is a selectable setting on the player's profile (an account-level setting, not the public profile); the player picks a built-in theme (Phosphor, Manila, Night Desk) and, separately, a drop-down for how it renders (normal, high contrast or a colour-blind mode, "if available", R's words; read as only the variants that theme provides, Proposed); each theme is self-contained, its colour-blind and contrast variants saved with its defaults; players can create custom themes that set any colour the built-ins set, in the UI; players can import and export themes; testing with colour-blind players is still owed (VER-14). Supersedes the design review's local-only recommendation (DEC-25 A, DEC-40 A). T1 is silent on GM forcing (T4). R ruled T2 to T6 the same day: see T9. | [07](07-apps.md#themes-and-player-appearance-settings) |
| T9 | Themes, R's rulings on T2 to T6, 2026-11-04. **T2:** "these settings are only for the player client", unless the question is where they should be stored to sync across clients; read as: the appearance setting and custom themes are client-side (whether cross-client sync is wanted in v1 stays open, T2 below). **T3:** "no limits on player theming" (no theme count, name length or override caps); a theme may name a built-in or custom theme as its base and store only the values it overrides, per variant. **T4:** "the Handler cannot force a change from one theme to another"; the Handler can force certain screen colours, highlights or effects that other game features describe once those are ruled (capability lock cards, synthesis §12, revision 4, with DEC-34 and GAP-33 open; intrusion cues, DEC-07), and their colours are included in every palette; R also asked for a solution for themes that lack colours a newer feature needs. DEC-07 stays unruled. **T5:** in v1 players likely share themes only externally, as exported files; R confers with D (Pending D). **T6:** all documents will eventually be rendered by our own pipeline (typst or another solution), so documents may be affected by theme; document colour tokens are in the palettes and custom themes may change them, with a document mode that shows a standard fixed scheme. Design details beyond these words are Proposed (T2, T3, T4, T6, T10, T11 below). | [07](07-apps.md#what-r-ruled) |
| T7 | Theme details, ruled by R 2026-11-04: (a) the chip text token names `onSuccess`, `onPartial`, `onFailure`, `onWarning`, `onLocked`, `onConfirm` are accepted; (b) a token for the window edge (Manila's outer-edge rule colour in the synthesis §6.1), set on every built-in theme and variant (name `windowEdge` from R's example; values computed in 07, Proposed); (c) invalid themes are rejected on import (whether `#RRGGBB` without transparency matters: answered and Fixed in 07, T11); (d) the first-launch default follows the OS brightness, as a System option beside the three built-ins in the theme selector, followed live, with the variant drop-down still applying and custom themes selectable by name; (e) D confirms the variant labels (Normal, High contrast, Red-green safe, Blue-yellow safe) and the System label (Pending D). | [07](07-apps.md#what-r-ruled) |
| T8 | Theme code placement, ruled by R 2026-11-04: a separate package. R's reason: the model may expand after v1 (theme distribution, per-campaign theme settings, custom icons, images, animations or more), so the structure is better in place now. Proposed: name `theme_core`, pure Dart, Dart SDK only (model, codec, validator, resolver, token registry, colour math, built-in themes as JSON assets); `ui_kit` keeps the widgets and the `ThemeController`; apps keep storage. 00's package map and dependency rules are amended. | [07](07-apps.md#layering), [00](00-overview.md#dependency-rules) |

### Backend

| # | Ruling | Where |
|---|---|---|
| FS1 | RTDB holds live play only; Firestore holds data at rest: archived operations, library, pack index (files stay in Storage), searchable account data. Answers B1. | [06](06-accounts-backend.md) |
| FS2 | Desktop reaches Firestore through a small hand-written REST client in `backend`, authenticated with the `firebase_dart` ID token (`getIdToken()` per request) [V-32]. Web uses FlutterFire `cloud_firestore`. | [06](06-accounts-backend.md) |
| FS3 | `archiveOperation` HTTPS function writes archives to Firestore with `firebase_admin_sdk`. Functions read and write RTDB through their own REST calls with the runtime default credential (no key files), scoped with `auth_variable_override`; a dedicated runtime service account per function group [V-33]. Each one that reaches RTDB gets `roles/firebasedatabase.admin`, no narrower custom role (R, 2026-10-20) [V-46]. | [05](05-migrator.md), [06](06-accounts-backend.md) |
| FS4 | Standard edition: structured queries on keyword/tag fields, no full-text search. Revisit Enterprise if text search is needed [V-36]. | [06](06-accounts-backend.md) |
| FS5 | Archived event and text logs are chunked into a subcollection to stay under 1 MiB per document [V-7]. | [05](05-migrator.md), [06](06-accounts-backend.md) |
| P9 | Badge sign-in via an HTTPS Dart function minting a custom token, conditional on probe 8.3 (condition met: a real custom token signs in on Windows and Linux [V-41]). PDF417 symbology; payload is only badge id + 256-bit secret, secret stored hashed. Service Account Token Creator on the runtime service account is a deploy-checklist item [V-33]. Badge packages not approved yet. | [06](06-accounts-backend.md) |
| P10a | Backend port and adapters, plus a document-store capability for Firestore. | [06](06-accounts-backend.md) |
| P10b | Three Firebase projects (dev, staging, prod); RTDB and Firestore rules tested in the Emulator Suite. | [06](06-accounts-backend.md), [08](08-testing.md) |
| P10c (RTDB) | The three items probe 8.6 left open [V-38], ruled by R 2026-10-20 ("I'll take your recommendations on P10c 1 and 2. Yes meta/locked should freeze."): `meta` cannot be deleted; signaling is keyed by uid (`signaling/$uid/...`, written by that uid or the GM); `meta/locked` also freezes signaling. Applied in `firebase/database.rules.json` and shown in the emulator [V-50]. The rest of the RTDB draft was approved by R 2026-10-21 ("The rest of the proposals in the draft are approved"; P1-P16, P18-P22, P24 in the library review sheet `architecture/rtdb-draft-review.md`). After archive a function deletes the live branches and keeps `meta` and `members` as a locked stub (R 2026-10-21, estimate flag 2 option a; members kept). The anonymous one-alias rule is in Firestore. | [06](06-accounts-backend.md#realtime-database-model-live-play) |
| P10c (phone box) | Ruled by R 2026-10-21. P17: "GM messages go into the box as well. The box should only be cleared once a mission ends." P23: "Remove it as per your suggestion" (the prototype's `phoneDraft` path is removed from the rules plan). The mission-to-spec-unit mapping waits on Q24 and Q7; clearing mechanism ruled 2026-10-21 ("For P17, let's go with your proposal"): `PhoneMessageSent` events stay the record and a function clears the box with admin REST after the archive is written. The head snapshot stays in RTDB (R 2026-10-21). | [06](06-accounts-backend.md#realtime-database-model-live-play) |
| P10c (rules gaps) | Ruled by R 2026-10-21: "I'll take your recommendations for 1 & 2. Anonymous players should not be able to join voice and video or send messages as age verification happens on account creation." Presence writes are refused once the operation is archived (the rules file marks this as `meta/status` = `archived`, set by the archive step (admin REST); the marker value is the implementation's choice); `meta` must carry `gm` and a string `status` that cannot be removed, and `locked` is a boolean; anonymous members cannot write signaling or send phone messages. Shown in the emulator [V-51]. Answers part of Q33 (what anonymous accounts can do). | [06](06-accounts-backend.md#rules-rulings-r-2026-10-21) |
| P10c (review follow-ups) | Approved by R 2026-10-21 ("Yes to all of these."): archive order lock, archive, clean-up; anonymous members cannot read signaling; phone messages need string `from` and `text` with `text` at most 2,000 characters (field names are the implementation's choice); `meta/locked` cannot be removed once set; non-member text log reads refused (check). Shown in the emulator [V-52]. | [06](06-accounts-backend.md#rules-rulings-r-2026-10-21), [05](05-migrator.md) |
| P10c (second review round) | Approved by R 2026-10-21 ("Yes let's fix those now"): only admin REST can set `meta/status` to `archived`; test run order lock, archive, clean-up; text log `alias:null` check; phone cap counts UTF-16 code units (documented, rule unchanged). Shown in the emulator [V-53]. | [06](06-accounts-backend.md#rules-rulings-r-2026-10-21) |
| P14 | HTTPS-only Dart functions: badge login, roles, payment webhook and store receipts (placeholders until concern 6), push via `firebase_admin_sdk` Messaging, pack publishing helper, `archiveOperation`. In-app inbox on RTDB at `/inbox/$uid`. | [06](06-accounts-backend.md) |
| B2 | Probe order: 8.6 RTDB rules prototype, 8.5 anonymous upgrade, 8.3 real custom token on Windows/Linux, 8.4 claim pickup, 8.1 queued write across restart; later 8.1c, 8.7, Storage through `firebase_dart`, long sessions. All five ordered probes are done [V-38]–[V-42] (8.4 on Linux only), as are FS2 (natural expiry on Linux [V-45]), 8.1b and B5 (Linux and Windows), and the FS3 least IAM role [V-46]. Status: [verification.md](verification.md#probe-status). | [06](06-accounts-backend.md) |
| B3 | Joins written by the GM client under RTDB rules; library verification under Firestore rules from the client; other admin-only RTDB writes through function REST. No Node function; the `firebase_admin` (appsup) lead is dropped. | [06](06-accounts-backend.md) |
| B4 | No App Check enforcement in v1 (enforcement would lock out desktop) [V-37]; protection from Auth and rules; App Check monitor-only on mobile and web; revisit if abuse appears. | [06](06-accounts-backend.md) |
| B5 | Encrypt the `firebase_dart` Hive box `firebase_auth` with `HiveAesCipher` after setup and before any auth use; key in the OS secure store via `flutter_secure_storage` 11.2.0. Guards: key access never fails silently, plus a plaintext-to-encrypted migration; a timeout for a locked Linux keyring. `hive` 2.2.3 is a direct dependency of `backend`, pinned exactly [V-34][V-35]. Accepted risk: `firebase_dart` depends on unmaintained `hive` and archived `firebaseapis` 0.2.0. | [06](06-accounts-backend.md) |
| B6 | Desktop calls Dart callables by full URL with a Bearer ID token and the `{"data"}` envelope [V-33]. | [06](06-accounts-backend.md) |
| Concern 4 | Destination GM approves alias transfers; the source campaign is notified (no consent); an alias in a running operation cannot move until it ends; the transfer request lives in Firestore under the destination campaign. | [06](06-accounts-backend.md) |

Ruled before this review and unchanged: archived logs are frozen, not converted; a plain-text rendering is kept beside them; the new log starts at `OperationMigrated`; the GM explicitly confirms the unrecoverable loss.

## Pending D

R wants D's approval on these before they are designed in full. The proposals are carried in a separate PR for R's meeting with D (Thursday 2026-10-22 at the earliest). Nothing approved in this spec depends on them beyond the reserved fields and interfaces noted.

| Item | What is undecided | Already fixed |
|---|---|---|
| C5/G6 occult check attribute | Which attribute the occult check uses. | Engine supports any attribute. |
| F3 (1) occult system | "Cast magic" as one roll kind with a GM-set DC, and how much of `OccultSystem` (ritual time, participants, focus items) stays. | Spells have no schema (R's game-rules model, 2026-10-16). |
| P3 pack shape | Exact files, fields and details of a content pack. An example pack is in the project library for D. | JSON + manifest; validator; annotations stripped. |
| W1 web hosting | Whether web hosting returns later, for onboarding new users. | Web is player-only for now. |
| Concern 7 physical dice | GM and remote players entering real dice faces on their own clients, behind a per-operation GM setting (off by default; without it entered faces are refused). | `source` field reserved on `CheckResolved`. |
| T5 theme sharing (owner R and D; next R and D meeting) | Whether themes are shared only externally as exported files in v1, as R expects, or also in the app (a gallery would go through moderation, [11](11-supplemental-features.md#library-and-public-content)). Added 2026-11-04 (T9). | Import and export of theme files (T1). Proposed: no in-app gallery, upload or moderation in v1. |
| T7 (e) theme labels (owner D; next R and D meeting) | D confirms the variant labels (Normal, High contrast, Red-green safe, Blue-yellow safe) and the System label in the theme selector; Proposed: the document mode label goes with them. Added 2026-11-04 (T7). | The variants and the System behaviour (T1, T7 d). |

## Open for R (themes)

Proposed in [07](07-apps.md#themes-and-player-appearance-settings), not ruled. These are what is left after T1, T7, T8 and T9; T5 and the T7 (e) labels are under [Pending D](#pending-d). Nothing built depends on them.

| Item | What is undecided | Proposed | Owner |
|---|---|---|---|
| T2 sync | Whether cross-client sync of the setting and custom themes is wanted at all in v1; whether "only for the player client" excludes the Handler console. | Local storage per client plus export and import in v1; optional sync later. If sync is added: owner-only `appearance/{uid}` (deferred in [12](12-firestore-collections.md#collections-at-a-glance)), never `agents/{uid}`, whose `keys().hasOnly` whitelist stays; the variant as a neutral rendering label with no health framing, because a synced colour-blind variant sits outside 11's real-personal-data list (alternatives then: variant local-only, or amend 11). | R |
| T3 safeguards and derived themes | Technical safeguards that are not theming limits; the base-and-overrides design. | Import file ceiling 1 MiB before parsing and base chain depth 32 (R can veto either); `base` (id plus token-set version) and sparse per-variant `overrides`; lookup own value, base chain, the fallback built-in (chain root, else `copiedFrom`, else brightness) for the variant, then its `normal`; cycle detection flags every member of a loop; missing base falls back with a notice and **Flatten**; export flattened by default, "overrides only" as an option; derived themes follow base edits and built-in updates (a feature and a risk), with **Detach (flatten)**. | R |
| T4 effect tokens | New effect and highlight token names and values; the outdated-theme solution; the effect-safety rule; player opt-out. | Existing design tokens for lock cards and cues (`locked`/`onLocked`, `warning`/`onWarning`, `anomaly`, `supervisor`, `rule`, `ink`, `inkMuted`); new `highlight`, `intrusionGround`, `onIntrusionGround`, `sceneTint`, initially reusing existing tokens until computed by the study's method; token sets with a version map; only tokens no theme in the chain supplies are filled from the fallback built-in, with a notice and **Add missing colours**; failing effect and document pairs use the fallback value inside that element only; the player's effects opt-out wins (DEC-16 A). | R |
| T6 document tokens and document mode | New document token names and values; document mode. | New `paperInkMuted`, `paperRule`, `paperStamp`, `paperRedact` from §6.1 ladder steps; a Document mode toggle on every document view (per view plus a remembered preference) showing a fixed, non-themeable standard paper set, also used for print and export. | R |
| T10 document renderer | The pipeline that renders documents (typst or another solution; no new dependency or tool without R's approval, CLAUDE.md §6); the print default. Related ideas: the synthesis "Forms and filing" section (print and export), cited by name. | Not chosen. Print and export use the standard paper set; DEC-29's black on white is the alternative print default. | R |
| T11 T7 follow-ups | Colour format Fixed (R, 2026-11-04). Still open: the `windowEdge` values; the `theme_core` name. | `#RRGGBB` for every token, `#RRGGBBAA` only for tokens marked alpha-capable (`sceneTint`, `highlight` in token set 1), alpha rejected elsewhere, contrast computed on the composited colour; `windowEdge` Phosphor `#C0D8C2`, Manila `#5F5348`, Night Desk `#B8D8E9` in all four variants (at least 3:1 against `desk`, `window` and `windowRaised`, computed from the design library's §6.1 values); package name `theme_core`. | R |

**T8, cost note.** The separate package costs one more pubspec, a layer-table entry, a workspace member, and an asset hand-off (Flutter loads the built-in JSON in `ui_kit` and passes it to the package, since `theme_core` cannot use the asset bundle). For v1 alone that is a little structure ahead of need; the upside R named (room for distribution, per-campaign themes, icons and animations) outweighs it, so no change is proposed.

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

## Concerns raised

Each was raised once, per CLAUDE.md §2, and R's answer stands.

1. **Firebase on desktop vs "all Flutter targets". Resolved by R:** `firebase_dart` on desktop [V-21], RTDB for live play, Firestore at rest over REST (FS1, FS2), HTTPS-only Dart functions; Linux required in v1.
2. **Web GM cannot host LAN. Accepted by R;** web is player-only for now (W1).
3. **Rulebook inconsistencies. Resolved by R (F1)** except the occult check attribute, pending D.
4. **Alias transfer approval. Ruled** (concern 4 above).
5. **Library verification workflow. Ruled** (concern 5 above).
6. **Payments. Deferred.**
7. **Physical dice. Field reserved;** feature pending D.
