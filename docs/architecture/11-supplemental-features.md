# 11. Supplemental features

Status: **ruled by R (2026-10-20)**, from D's approved feature list "B.A.R.D. Supplemental Materials". This chapter records the decided parts. Items that depend on the operation/mission model (X0) wait for R's meeting with D and are not designed here. They are listed at the end. Nothing here is implemented yet.

Where this chapter changes an earlier ruling, it says so under [Amendments to earlier chapters](#amendments-to-earlier-chapters). Those chapters are updated in a later change, after the probe-findings update to this spec lands. Design details R has not ruled on individually are marked **Proposed**. Question ids (Q6, Q24 and so on) trace to the working record `architecture/supplemental-features-reconciliation.md` in the project library.

## Terminology (ruled, rename pending)

R ruled the game's terms on 2026-10-20:

| Term | Meaning |
|---|---|
| Agent | The player's account profile, in-world and fictional. |
| Alias | A character played inside an operation. An agent owns aliases. |
| Operation | The whole campaign, spanning many game sessions, months or years. |
| Mission | A segment of play inside an operation. One operation has many missions. Character and player data is preserved between missions. |
| Handler | The GM. A paid account tier (see [Clearance tiers](#clearance-tiers)). "Tier" in this chapter always means an account tier, not a content tier as in [02](02-rules-packs.md#content-kinds-and-tiers). |

The rest of this spec still uses "campaign" for the long-running game and "operation" for one session (glossary in [README.md](README.md)). The spec-wide rename, and which unit owns an event log, wait on X0. This chapter uses R's terms.

## Agents, aliases and profiles

- **Fictional profiles.** Every agent and alias profile field describes the in-world character, not the real person: name, sex, pronouns, blood type, organ-donor status, ethnicity, eye colour, height, weight, shoe size, handedness, profile image. None of it is personal data. Each alias carries its own copy of these fields.
- **Fixed agent fields.** Two fields cannot be edited: the **badge number** (generated, see [Badge numbers](#badge-numbers)) and the **sign-up date**, set at creation. R's third fixed field, the player/handler account type, was replaced by the handler tier (below).
- **No fixed account type.** Handler is a paid clearance tier, not a type chosen at sign-up. Handlers own aliases, and those aliases can join other handlers' operations.
- **Anonymous accounts** get no agent profile and no badge number until they upgrade. They keep the existing rules: one alias, can join, cannot host or create content ([06](06-accounts-backend.md#account-model-fixed-concepts-proposed-fields)).
- **Private agent.** The agent's information is redacted on the public profile, and the alias list is partly hidden.
- **Private alias.** The alias is left out of the alias list on the agent's public profile.
- **Public profile.** The agent's public profile shows the agent, the public aliases, the operations they took part in and the missions they completed. The public badge links to it. Where the mission history comes from waits on X0.
- **Document split.** Firestore rules act on whole documents, so hidden fields belong in a separate document [V-48]. Public profile data, owner-only data and private alias data are therefore separate documents. This shapes the Firestore collection draft (P10c).

## Real personal data

Only these fields are real data about the real person: **age**, **occupation** (optional), **content creator** (yes/no), **email**, **gender**, **feature feedback**, and **payment information**.

- **Age** is stored as a bracket: under 12, 12-17, 18-25, 26-35, 36-45, 46-55, 56+. No birth date is stored.
- **Payment information is never stored in our Firestore.** The payment provider or app store holds it. Payments themselves stay deferred (concern 6).
- **Email** stays in Firebase Auth and is never copied into a public profile.
- **Proposed:** these fields live in owner-only documents and are never indexed for search.
- **Proposed:** feedback goes to a write-only collection for users, readable by admins in the console.
- **Consent.** The privacy policy and consent screens cover only these fields, not the fictional profile. The consent screen also holds the opt-in that sets the default for appearing in published missions (a gameplay setting, see [Library and public content](#library-and-public-content)).

## Clearance tiers

D's tiers, as given by R:

| Tier | Clearance | Access |
|---|---|---|
| Anonymous user | 0 | No data access |
| Free user | 1 | Clearance 1 data; clearance 2 summaries |
| $2.99 user | 2 | Clearance 1 and 2 data; clearance 3 and 4 summaries |
| $5.99 user | 3 | Clearance 1-4 data |
| Handler | 4 | Clearance 1-4 data; can temporarily redact files for handled agents. Hosting and GM tools come with this tier (R, 2026-10-20) |
| Developers | 5 | Internal information no one else has, including packs and rulesets still in testing |

"Data" means entries in the glossary, bestiary, item catalog and mission/operation library. A whole entry, or a section of one (a field or part of a description), can be locked behind a clearance level (D).

- **Claim.** One custom claim holds the account's tier, set by the roles function ([06](06-accounts-backend.md#roles)). It replaces the spec's loose "tier" claim. Rules read it from `auth.token` [V-9]; claim-based rules over the desktop REST client are still unproven [V-32], and claim pickup after a change follows probe 8.4.
- **Per-tier lookup.** Access is not "clearance ≥ N". For example, a $5.99 user reads level-4 data, and only some tiers see summaries. The roles function and rules use a per-tier list of the **data levels** and **summary levels** each tier may read. Entry levels run 1-4.
- **Gated sections are separate documents** (follows from [V-48]). Each gated section has a data document and a summary document, readable only by tiers granted that level.
- **Summaries.** Every mission gets a summary; only some missions are redacted.
- **Hosting and GM tools** (hosting, the panic button, GM tools on the companion app, redaction) check for the handler tier.
- **Lapsed handler tier.** The handler's operations stay readable and can be archived, but no sessions run and no new operations start until the tier is active again.
- **Handler redaction** is enforced by the app, per operation, with an expiry, like perspective filtering ([03](03-protocol.md#visibility-and-perspectives): immersion between honest clients, not security).
- **Developers' testing content.** Developers see internal information, including packs and rulesets still in testing (R). Proposed: pack index entries and library items carry a status (`testing` or `released`), and rules let only clearance 5 read `testing` entries; clearance 5 stays separate from the admin claim.
- **Bundling and caching.** Level-1 (free) content ships inside the apps. An anonymous user digging it out of an install is accepted. All other gated data is fetched for entitled users and cached on the device for offline use. Copying non-secret cached content is accepted, so clearance gates fetching, not cached data. This changes [02](02-rules-packs.md#distribution) only for gated lore above level 1, which is not bundled. Rules data the engine needs to run play is not gated.
- **Until payments exist,** the tier claim is set by hand through the roles function, and mission submissions are open to every full account.

## Badges and sign-in

There are two separate codes (R, 2026-10-20). This replaces P9's single printed sign-in badge.

| | Public badge | Sign-in code |
|---|---|---|
| Purpose | Opens the agent's public profile | Signs the player into a desktop, web or mobile session |
| Visible to | Everyone; printed on physical objects | Only the player, on their signed-in phone |
| Payload | An https link to the public profile, keyed by **badge number only** (never the agent id, which is the Firebase Auth uid) | A short-lived, single-use credential |
| Symbology | PDF417 (for the look, R) | PDF417 (proposed, from D's list; D to confirm) |
| Scanned with | The companion app | The other device, or the reverse flow below |

### Badge numbers

- 16 digits, non-sequential, stored as a **zero-padded string**. Leading zeros matter, and 16-digit values exceed the 53 bits of integer precision `int` has on the web [V-14].
- `0000000000000000` to `0000000000000099` are reserved and assigned by hand through the console. D's badge number is `0000000000000013`.
- A function generates numbers using a seed stored in the cloud (R). Approved method: a **keyed permutation** of a counter over the valid range (100 to 9999999999999999), so generated numbers look non-sequential and never repeat each other. A create-only-if-absent document per number (`badgeNumbers/{n}`) is a backstop against clashing with hand-assigned numbers. The seed sits in an admin-only location.

### Public profile page

Scanning a public badge with the companion app opens the profile in the app. The link also opens a public profile page on Firebase Hosting for people without the app. Opening https links directly in the app comes later with [09-2](09-open-decisions.md#apps) https support.

### Sign-in code

- Short-lived and single-use (R). Proposed flow: the signed-in phone asks a function for a fresh code (for example valid for 60 seconds). The other device scans it and sends it to the badge-login function, which returns a custom token (the P9 mechanism, conditional on probe 8.3).
- **Reverse flow, also supported:** the desktop or web client shows a one-time code, and the signed-in phone scans it and approves the sign-in. Many desktops have no camera, so this flow avoids needing one.
- Neither code can create a sign-in without the backend.

### LAN join QR

The LAN QR carries only join information (host address, operation id, one-time join code), never credentials. Identity comes in `hello` ([03](03-protocol.md#messages)).

## Invite links

The invite link is `bard://join/<op>?invite=<token>`. A Firestore invite document holds an expiry and a use count. Redeeming it creates a join request that the handler approves, with an RTDB inbox ping to the handler ([Live updates](#live-updates-outside-the-live-play-tree)). The alias is chosen after the link opens, so the link drops 09-2's `alias=` parameter.

## Messaging

- **Stat-gated broadcast (approved engine change).** The GM sends a message that only aliases meeting a stat condition receive. Example: "a low groaning voice is heard nearby", delivered only to aliases whose WIL is below a value.
  - Proposed command: `BroadcastToQualifying(text, condition)`.
  - The GM's engine evaluates the condition against each alias's state; the UI never does.
  - The engine records one event with visibility `aliases[...]` naming the qualifying aliases, so the existing filtering delivers it ([03](03-protocol.md#visibility-and-perspectives)).
  - The condition needs new comparison nodes in the data-only expression trees (P4). It stays GM-only.
  - Open: whether recipients can see who else received it.
- **Phone.** Handler → alias, alias → NPC and alias → alias messaging use the in-game phone ([04](04-session.md#in-game-phone)). The UI tells players that the handler can read alias → alias messages.
- **Report.** Messaging has a report option. It is the only content with one.
- **Contact book.** The handler releases NPC contact details to chosen aliases (D's list). Proposed: an event `ContactRevealed` visible to those aliases. How it persists between missions is part of X0.

## Library and public content

- **All public content is moderator-approved before it becomes available** (R). That covers mission submissions, public operation listings, public profiles and profile images. Proposed mechanism: a pending → public queue enforced by Firestore rules, like the library ([06](06-accounts-backend.md#library-fixed-concern-5-ruled-by-r-2026-10-20)); Dart functions deploy no Firestore triggers [V-23].
- **Moderators.** R and D are the only moderators, for missions and all other public content; concern 5 is unchanged. The `moderator` claim (06 Roles) is assigned once more moderators are chosen.
- **Mission submissions.** Missions become a library kind, submitted through forms for the handler and the players (D's list). Every published mission gets a summary and a clearance level. What a published mission contains, and its id, depend on X0.
- **Appearing in a published mission** is a per-player gameplay setting. Its default comes from the opt-in on the consent screen.
- **Public operations.** Handlers can mark an operation public and virtual ("virtual" means played online, not in person). Public operations are listed to signed-in users, and players can request to join. Proposed: the request is a Firestore document under the operation's record, approved by its handler, like a transfer request (concern 4); once approved, the handler's client writes the membership under RTDB rules as today (B3).
- **Readers.** Firestore search and listings are for signed-in readers, limited by clearance. Firestore rules can cap page size [V-49], which limits scraping costs given per-read billing (FS4) and no App Check enforcement (B4).

## Game manual

The in-app browseable manual uses the same gating as the PDF manual: it is available to the handler tier, or to anyone who buys it. That purchase is a payment product (concern 6). The manual content is D's.

## Fake occult websites (provisional, Q12 with D)

- A site is a document of typed blocks (heading, text, image, link to another fake page, form-like widgets), rendered by `ui_kit`. Raw HTML or JavaScript is never allowed.
- Provisionally (R, D to confirm): sites are written by handlers, scoped to an operation, and shared beyond it only later through the library with moderation.
- The handler controls access per mission or operation (D's list). Proposed: an access list on the operation's Firestore record, and an event (for example `SiteRevealed`, visible per alias) when a site is unlocked in play; where that event lives waits on X0.

## Panic button

- **Who:** the handler. The panic button is optional.
- **Flow:** a request to an API or function we designate, which returns an LLM response built from a prompt we create, with base information from D and information from the operation (R). Proposed: an HTTPS Dart function that adds the prompt, calls the provider and returns the response to the handler only. The provider is named by R at implementation. The function never imports the engine (F4), and the API key never leaves the server; how Dart functions read secrets is unverified [U].
- **What the prompt may use:** pack data, information the GM provides, information about the operation's aliases, and information we provide at generation time. **Never a player's personal information or messages.**
- **Warning:** each use shows that the response is AI-generated and may use operation data.
- **Proposed limits:** rate limits per handler and a response size cap. It needs a network connection.

## Companion app

- **v1 platform:** Android.
- **Backend on mobile:** the normal Firebase client SDK (FlutterFire, Android support per [V-10]), through the `FlutterFireAdapter` (P10a).
- **GM tools** (item creator, panic button) are available to the handler tier, built from shared `ui_kit` editor widgets.
- **Character sheet scanning:** OCR reads D's printed sheet and fills the character-creator UI (R). Proposed: the player reviews every field before saving, values go through the same validation as manual entry, and parsing is anchored to D's sheet layout. The OCR engine (on-device or a cloud API) is named by R at implementation.
- **Badges:** scans public badges and shows the player's own sign-in code ([Badges and sign-in](#badges-and-sign-in)).
- **Search:** level-1 glossary, bestiary and item data is bundled and searched on the device, offline, by signed-in accounts the tier allows. Higher levels are searched on the device once fetched and cached. Archived missions are searched in Firestore with keyword and tag fields only (FS4); how mission records are stored waits on X0.
- **Offline access** follows [06](06-accounts-backend.md#offline-accounts-fixed-requirement).

## Supplemental-materials tool (deferred)

The tool for handlers to make in-setting materials combines the Typst work ([02](02-rules-packs.md#documents-typst-later)) with an RTF editor. It is deferred until that stage.

## Live updates outside the live-play tree

The desktop Firestore client is REST-only (FS2), and Firestore has no live listening over REST [V-47]. Proposed: live updates outside an operation's RTDB tree (join requests, transfer approvals, moderation results) arrive as an RTDB `/inbox/$uid` ping (P14), followed by a Firestore read.

## New dependencies (not approved)

These go to R when their feature is scheduled:

- a camera or image picker (sheet scanning, profile images);
- `barcode` (PDF417 rendering and printing);
- `mobile_scanner` (companion scanning);
- `flutter_zxing` or a USB 2D scanner (desktop scanning of sign-in codes);
- a rich-text renderer (manual, websites);
- the OCR engine and the LLM provider, both named by R at implementation.

## Amendments to earlier chapters

These are applied to the named chapters in a later change:

| Ruling | Changes |
|---|---|
| P9 | The printed badge is a public profile link (PDF417, badge number only, no secret). Sign-in moves to a short-lived, single-use code shown on the signed-in phone, plus the reverse flow. Affects [00](00-overview.md) Accounts row, [06](06-accounts-backend.md) account model `badges[]`, the RTDB draft's `/users/$uid/badges`, the Badges section and the badge-login function row, and [09](09-open-decisions.md) P9. |
| 09-2 | Invite links use `bard://join/<op>?invite=<token>` with no `alias=`. Affects the Routing rows in [00](00-overview.md) and [07](07-apps.md). |
| P10a | Mobile uses `FlutterFireAdapter` (normal Firebase client SDK); `firebase_dart` stays on Windows and Linux. Android is the companion's v1 target. Affects [00](00-overview.md) Targets, [06](06-accounts-backend.md) Stack and platform text, and [07](07-apps.md) (the companion row gains GM tools for the handler tier). |
| 06 Roles | The "tier" claim becomes the clearance tier claim with a per-tier lookup. Handler features check it. The `moderator` claim is assigned once moderators beyond R and D are chosen. |
| 06 Account model | No player/handler type. The agent gains fictional profile fields, a badge number (string) and a sign-up date. Anonymous accounts have no profile or badge number. |
| 02 Distribution | Gated lore above level 1 is not bundled. Packs and library items gain a `testing` / `released` status. |
| 01 Engine | A new command for the stat-gated broadcast, plus comparison nodes in condition expressions. Proposed `ContactRevealed` and `SiteRevealed` events. |
| P14 | Adds functions: sign-in code minting, badge-number generation, the panic-button proxy. |

## Currency (provisional, D to confirm)

Provisionally (R): D defines the currency name, prices, starting funds and income in pack data, and the engine gets a generic `Funds` vocabulary (a component plus transfer commands and events), so balance arithmetic stays in the engine. D confirms at the meeting (Q6). How money moves between missions waits on X0.

## Waiting on X0 (R's meeting with D)

Under R's terms an operation is the whole campaign, but the spec still gives each operation (one session) its own event log. Which unit owns the log decides the items below, so they wait for R's meeting with D:

- **Q24:** whether the event log belongs to the operation, stored in mission segments, or to each mission.
- **Q5:** requests made between sittings (purchases, contact releases), and whether purchases may auto-confirm.
- **Q7:** where messages between sessions live.
- **Q9 (content):** what a published mission contains and how it is identified.
- Bank, storefront and wallet between missions; "last 3 completed missions"; how the contact book persists.
- **Q33:** what anonymous (clearance 0) accounts can do.
