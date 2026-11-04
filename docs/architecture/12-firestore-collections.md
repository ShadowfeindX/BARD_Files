# 12. Firestore collections (P10c, Firestore part)

Status: **Proposed**, awaiting R. This is the Firestore half of P10c; the RTDB half is Fixed in [06](06-accounts-backend.md#realtime-database-model-live-play). Nothing here is built. *Naming note (2026-11-03):* the tree is Campaign > Operation > Mission > Episode. The old `operations/{opId}` node is split into campaign, operation and episode records (see "Campaign, operation, mission and episode records"); the RTDB live tree is `/episodes/$ep` ([06](06-accounts-backend.md#realtime-database-model-live-play)). The rules and indexes below have **not** been run in the Emulator Suite; every behaviour claim that depends on that is marked `[U]` (unverified). Verified facts carry their V-id.

This chapter fills the gap left by [06](06-accounts-backend.md) (FS1 to FS5 chose Firestore for data at rest and a hand-written REST client on desktop). It names the collections, the document shapes, the security rules and the composite indexes. Account fields come from [11](11-supplemental-features.md). Archive layout follows [05](05-migrator.md). The event-log unit is ruled (the Episode); the few held items are listed at the end.

## Constraints that shape the design

| Constraint | Consequence | Source |
|---|---|---|
| Rules read whole documents; a field cannot be hidden from a reader who may read the document. | Anything with a different audience is a separate document. | [V-48] |
| At most 10 `get`/`exists` per request. | Rules use claims first and at most three lookups per path. | [V-7] |
| 1 MiB document cap. | Archives are chunked at about 800 to 900 KiB. | [V-7] |
| Page size can be capped in rules with `request.query.limit`. | Every `list` rule below calls `pageOk()`. | [V-49] |
| Desktop has no live listeners; REST with `getIdToken()` on every request. | Collections are read by query or by id, never by subscription. Freshness comes from refetch. | [V-47] |
| `FAILED_PRECONDITION` means a missing composite index. | Every query the app runs is in the index list below. | [V-43] |
| Claim-based rules work after a forced token refresh. | `tier`, `arbiter`, `moderator` claims are read from the token. A tier change takes effect after a forced token refresh (a plain refresh did not pick it up [V-42]). | [V-43] |
| Standard edition: no full-text search. | Keyword and tag arrays, queried with `array-contains`. | FS4 |
| Dart functions have no Firestore triggers. | Function work is HTTPS-only; clients call it explicitly. | [V-23] |
| Archives are written by a function with `firebase_admin_sdk`. | Clients never write archive documents. | FS3 |

Claims used by rules (set by the roles function only; the claim is the only copy of the tier): `tier` (0 to 5), `arbiter` (the library verification claim, held by R and D, ruled in 06 Library and 11; token key named by R 2026-10-21) and `moderator` (assigned later when more moderators are chosen, 11). `admin` is not used in content rules. What each tier may read is not a claim: it is the lookup document `tierLevels/{tier}` (`{ summaryLevels, dataLevels }`, entry levels 1-4; 11 "Per-tier lookup"), one `get`, so R and D change the map in the console without re-issuing claims or forcing token refreshes [V-42]. `[U]` Proposed. Anonymous accounts are tier 0 and have `firebase.sign_in_provider == 'anonymous'`.

## Collections at a glance

| Collection | Document id | Audience | Written by |
|---|---|---|---|
| `agents/{uid}` | account uid | owner (private fields) | owner, function at creation |
| `appearance/{uid}` | account uid | owner only | owner. **Deferred, pending T2**: R ruled the appearance settings "only for the player client" (T9, 2026-11-04), read as client-side storage; this document exists only if R wants cross-client sync ([07](07-apps.md#where-it-is-stored-t2-client-side)). Not in v1 unless R says so; no rule drafted below |
| `profilesPublic/{badge}` | badge number (never the uid) | anyone (public page) | moderator, after approval of `profilesPending` |
| `profilesPending/{badge}` | badge number | owner, moderators | owner; deleted on approval |
| `badgeNumbers/{n}` | 16-digit badge number | function only | function |
| `signInCodes/{code}` | single-use code | function only | function |
| `aliases/{uid}/items/{aliasId}` | generated id; `anon` for tier 0 | owner | owner |
| `campaigns/{campaignId}` | campaign id | campaign members, GM | GM |
| `campaigns/{campaignId}/members/{uid}` | account uid | the member (own entry), GM | GM |
| `campaigns/{campaignId}/invites/{token}` | invite token | GM | GM |
| `campaigns/{campaignId}/joinRequests/{uid}` | requester uid | GM only | requester (public campaigns) or the invite function; GM updates |
| `campaigns/{campaignId}/transfers/{id}` | generated id | GM (destination), requester | alias owner creates; GM decides |
| `tierLevels/{tier}` | tier number | signed-in | console only |
| `operations/{opId}` | operation id | campaign members, GM | GM |
| `operations/{opId}/missions/{missionId}` | mission id | campaign members, GM | GM; function (summary) |
| `episodes/{episodeId}` | episode id (same as the RTDB key) | episode members, GM | GM; function (archive) |
| `episodes/{episodeId}/members/{uid}` | account uid | the member (own entry), GM | GM (see canonical copy) |
| `archives/{episodeId}/chunks/{n}` | chunk number | episode members, per audience | function only |
| `archiveIndex/{episodeId}` | episode id | episode members | function |
| `libraryPending/{id}` | content id | owner, moderators | owner; moderator (revocation) |
| `libraryPublic/{id}` | content id | summary levels per tier | moderator |
| `libraryData/{id}` | content id | data levels per tier | moderator |
| `packIndex/{packId}` | pack id | signed-in (public packs), owner | pack owner; moderator for public |
| `listingsPublic/{campaignId}` | campaign id | signed-in full accounts | moderator, after approval |
| `listingsPending/{campaignId}` | campaign id | GM, moderators | GM |

Names follow the library's "pending then public" model ([11](11-supplemental-features.md)). Pending and public are separate collections, not a status field, so that a public query never has to filter out unapproved content and a rule cannot be fooled by a status edit.

## Accounts

### `agents/{uid}` (private)

Owner-only account data: the section 10 real-data fields (the only real personal data allowed, 11) plus the badge and a privacy flag. Created by a function when an account becomes a full account (first full sign-in or upgrade). Tier 0 (anonymous) accounts have **no** `agents` document, no profile and no badge ([11](11-supplemental-features.md)).

```json
{
  "badgeNumber": "0000000000000013",
  "createdAt": "<timestamp>",
  "ageBracket": "26-35",
  "occupation": "string",
  "creator": false,
  "gender": "string",
  "private": false
}
```

- `private` hides the agent on the public profile (11: redacted); the owner may edit it.
- Real data is section 10 only: age bracket, occupation, creator flag, gender. **Email stays in Firebase Auth** and is not copied here (11). Payment data is never in Firestore. The tier lives only in the claim.
- `badgeNumber` and `createdAt` are written by a function (a client cannot pick its own badge). `ageBracket` is set at account creation (age verification happens then, 06) and is not owner-editable; the owner may edit `occupation`, `creator`, `gender`, `private`. Rules whitelist exactly these keys (`keys().hasOnly`), so no other personal field can be added.
- `ageBracket` is one of `under 12`, `12-17`, `18-25`, `26-35`, `36-45`, `46-55`, `56+`.

### `profilesPublic/{badge}` (fiction, public)

The in-world profile page (served by Hosting; [11](11-supplemental-features.md)). The document id is the **badge number**, and the document carries no uid: the public badge payload is keyed by badge number and never exposes the Auth uid (11). Fictional fields only; nothing here is real personal data. Ownership is proven in rules by the `agents` document (`badgeNumber` of the caller). Because rules read whole documents [V-48], `profilesPublic` holds only the **redacted, approved** form: a private agent (`agents.private`) is published with the `fiction` block omitted. Image paths are keyed by badge, never by uid, and profile images are moderated like profiles; their Storage rules are **Held**.

```json
{
  "badgeNumber": "0000000000000013",
  "fiction": {
    "name": "string", "sex": "string", "pronouns": "string", "bloodType": "string",
    "organDonor": false, "ethnicity": "string", "eyeColour": "string",
    "heightCm": 0, "weightKg": 0, "shoeSize": "string", "handedness": "string",
    "profileImagePath": "storage path or null"
  },
  "updatedAt": "<timestamp>"
}
```

The `fiction` fields are the list in 11 (name, sex, pronouns, blood type, organ-donor status, ethnicity, eye colour, height, weight, shoe size, handedness, profile image); value types are Proposed. The public page also shows the public aliases, operations and completed missions (11); where that history comes from waits on X0, so those lists are **Held**.

Public content is moderator-approved first, so an edit goes to `profilesPending/{badge}` (same shape plus `private` (copied from `agents.private`) and `submittedAt`; the `fiction` sub-keys are checked by the moderator, not by rules) and a moderator writes it into `profilesPublic` and deletes the pending document in one batched commit (a batch is atomic; the public create rule checks `!existsAfter` on the pending document). Moderation by client write under rules extends the B3/Library ruling in 06; a function stays the fallback "if the rules get awkward" (06). A function-based approval is the alternative if R prefers (see questions).

### `badgeNumbers/{n}` and `signInCodes/{code}` (function only)

- `badgeNumbers/{n}`: `{ uid, issuedAt }`. Lets the companion scan resolve a badge to an account. Clients cannot read or write it; a function resolves a scan and returns only what the scanner may see. Numbers 0 to 99 are hand-assigned (D is `0000000000000013`). The number is a keyed permutation computed in a function, so it is not derivable from the uid.
- `signInCodes/{code}`: `{ uid, expiresAt, used }`. Single use, issued by a function. A TTL policy on `expiresAt` removes stale codes as clean-up only: TTL deletion is lazy (up to about a day after expiry; figure from the Firestore docs, `[U]`), so the redeeming function checks `expiresAt` and `used` inside a transaction and never relies on deletion.
- `createAgent` (one HTTPS function, Proposed): verifies the caller is a full account with no `agents` document, generates the badge number, creates `badgeNumbers/{n}` only if absent, writes `agents/{uid}` (age bracket from account creation) and sets the tier 1 claim.

## Aliases (characters)

`aliases/{uid}/items/{aliasId}` is private to the owner (11: these fields are owner-only documents, never indexed for search).

```json
{
  "aliasId": "globally unique id, client-generated (20+ random chars), also for the anonymous alias",
  "private": false,
  "name": "string",
  "fiction": { "...": "same fields as the profile; each alias carries its own copy (11)" },
  "summary": "string",
  "packPin": { "packId": "string", "version": "string" },
  "sheetRef": "string or null",
  "tags": ["string"],
  "createdAt": "<timestamp>",
  "updatedAt": "<timestamp>"
}
```

**Anonymous one-alias rule** (moved from RTDB to here, [06](06-accounts-backend.md)): a tier 0 account may create only the document `aliases/{uid}/items/anon`, and only if it does not already exist. A full account may create any id. A second alias for an anonymous account is therefore a refused `create` on an existing document, or on any id other than `anon`.

**The document key is not the alias id.** The id used in `members/{uid}.aliasId` and in every audience (`alias:<aliasId>`, RTDB and archives) is the `aliasId` **field**, a globally unique random value, so two anonymous players (both stored under the key `anon`) never share an audience. The GM host refuses to admit two members with the same `aliasId`. `private` leaves the alias out of the public alias list (11).

The alias sheet and play state (inventory, skills, contacts) are engine components, not fields of this document; they live in the GM's store during play and in the archive afterwards ([05](05-migrator.md)). Carrying a character's state between missions waits on Q24 and X0.

## Campaign, operation, mission and episode records (R, 2026-11-03)

The tree is Campaign > Operation > Mission > Episode ([11](11-supplemental-features.md#terminology-ruled)). R ruled on 2026-11-03 that live-game data gets its **own Firestore node**, `episodes/{episodeId}`, kept behind its own rules instead of mixed with handler-level data. R-A1 and R-A6 put pack pins, base settings, join links, invites, listings and the player roster at the **campaign**, so the old `operations/{opId}` document can no longer own them. Each level is a top-level collection that names its parents by id:

| Node | Holds | Read by | Written by |
|---|---|---|---|
| `campaigns/{campaignId}` | `name`, `gmUid`, `memberUids`, `packPins`, `settings` (base), `visibility`, `virtual`, `status`; subcollections `members`, `invites`, `joinRequests`, `transfers` | campaign members, GM | GM while a handler; functions |
| `operations/{opId}` | story arc: `campaignId`, `gmUid`, `name`, `status`, `order`; subcollection `missions` | campaign members, GM | GM while a handler |
| `operations/{opId}/missions/{missionId}` | `title`, `status`, `aliasIds` (who takes part, R-A6), `settings` (per-mission overrides, R-A1, R-C1), then `summary` and timestamps | campaign members, GM | GM while a handler; archive function writes the summary fields |
| `episodes/{episodeId}` | live-game record: `campaignId`, `operationId`, `missionId`, `gmUid`, `memberUids`, `engineMajor`, `status`; subcollection `members/{uid}` (the searchable copy of RTDB `members`) | members of that episode, GM | GM while a handler; archive function sets `archived` |
| `archiveIndex/{episodeId}`, `archives/{episodeId}/chunks/{n}` | the archived log of one episode and its index | members of the episode, per audience | function only |
| `listingsPending/{campaignId}`, `listingsPublic/{campaignId}` | public listing of a campaign that takes join requests | GM and moderators; signed-in full accounts | GM; moderator |

What moves out of the old `operations/{opId}` document: `memberUids`, `packPins`, `visibility` and `virtual` go to the campaign; `engineMajor` and the episode's `memberUids` go to the episode; the `members`, `invites`, `joinRequests` and `transfers` subcollections go to the campaign (members also get a per-episode copy under the episode); `missions` stays under the operation; listings are keyed by campaign. The campaign document lives at top-level `campaigns/{campaignId}` (R, 2026-11-03, question 9 below).

RTDB stays the canonical store during play (06): the live tree is `/episodes/$ep`, and its `members` move to the campaign in a later gated row (R-A6). The phone box lives in the episode's RTDB tree and clears when the operation ends (R, 2026-11-03), so it is not part of the episode archive clean-up. After a mission is marked complete or submitted, everything but the latest snapshot is removed (R-A3); that pruning step is a later row.

## Campaigns, operations and episodes

### `campaigns/{campaignId}`

```json
{
  "name": "string",
  "gmUid": "string",
  "memberUids": ["uid"],
  "packPins": [{ "packId": "string", "version": "string" }],
  "settings": { },
  "status": "open | archived",
  "visibility": "private | public",
  "virtual": false,
  "createdAt": "<timestamp>",
  "updatedAt": "<timestamp>"
}
```

- `memberUids` is a denormalised copy of the campaign's member documents, so "campaigns I am in" is one indexed query and rules test membership without a `get` against the 10-lookup cap. It always contains `gmUid` (the GM cannot drop out). It is shown to every member, which is acceptable inside a campaign (11 keeps the uid out of *public* payloads only). Provisional caps: `memberUids` at most 20, `packPins` at most 5.
- `packPins` is the campaign's pack version pin (R-A1: one pin for the whole campaign, so characters' numbers do not change between missions). `settings` holds the base settings each new mission copies; the Q5 request auto-confirm default lives here (R-C1). Its keys are the engine's settings vocabulary and are not whitelisted by rules `[U]`.
- Only the GM creates and edits the document, and only while a handler (`tier() >= 4`); a lapsed handler keeps read and archive access only ([11](11-supplemental-features.md)). `gmUid` cannot change after creation. `status` becomes `archived` only through a function (admin SDK); rules refuse a client write of `archived`, matching the RTDB ruling (06). `virtual` means played online (11).
- Writing `memberUids` is allowed to the GM only; joins go through the GM (invite or request approval), never a self-add.
- The Handler persona (R-A4) is campaign-owned; its document shape is a later row and is not drafted here.

### `campaigns/{campaignId}/members/{uid}`

`{ joinedAt }`. A player account in the campaign roster (R-A6). Which of the player's aliases take part in which mission is `missions/{missionId}.aliasIds`, not this document. The GM client writes this document and `memberUids` in one batch. The `getAfter` check is one-way: a member document needs a `memberUids` entry, but a `memberUids` entry without a member document is not refused `[U]`. A member reads only their own entry and cannot list; the GM reads all. `[U]` Whether the roster also records which aliases a player brought into the campaign waits on the RTDB `members` row (R-A6).

### `campaigns/{campaignId}/invites/{token}`

`{ createdBy, expiresAt, maxUses, uses, aliasHint? }`. The token is the document id and also the deep link. The link names the campaign, so the canonical link becomes `bard://join/<campaignId>?invite=<token>` (09-2 said `<op>`; the route change belongs to the campaign-members row). Only the GM, while a handler, reads and writes the collection. A joiner presents the token to a function that validates it, increments `uses`, writes `joinRequests/{uid}` with admin access (so a private campaign accepts it) and pings the GM's RTDB inbox. The handler approves as for any join request (11). `[U]` The function is not specified yet.

### `campaigns/{campaignId}/joinRequests/{uid}`

Join request from a non-member (11). Not the same as the RTDB `requests` branch, which holds in-play requests from members. `{ aliasId, aliasKey, message?, status: 'open', createdAt }` (`aliasKey` is the key of the requester's own alias document; the rule checks that its `aliasId` field equals the claimed `aliasId`, so nobody can claim another player's audience), keys whitelisted. Any signed-in account, anonymous included, creates one document keyed by their own uid on a campaign whose `visibility` is `public` and `status` is `open`; invites reach private campaigns through the invite function. `message` is free text and therefore allowed **only for full accounts** (R: no messaging for tier 0). The invite function applies the same no-message rule for tier 0. The requester cannot read it back; the GM, while a handler, reads, updates `status`, and deletes.

### `campaigns/{campaignId}/transfers/{id}`

Alias transfer request (concern 4, Fixed): `{ fromUid, aliasId, aliasKey, sourceCampaignId, status: 'offered' | 'accepted' | 'declined', createdAt }`, a document under the **destination** campaign, approvable only by its GM. The source campaign is notified (a function writes to the source GM's inbox) and does not consent. An alias in a running episode cannot move until that episode ends, which rules cannot check, so a function performs the move on an accepted request and refuses a running source `[U]`.

### `operations/{opId}`

`{ campaignId, gmUid, name, status: 'open' | 'complete', order, createdAt, updatedAt }` (status values Proposed, not ruled). A story arc inside the campaign; operations are sequential (D, 2026-10-29), `order` keeps them in sequence. `gmUid` is copied from the campaign so the write rule needs no lookup; read access is by campaign membership (one `get`). Written by the GM while a handler; `campaignId` and `gmUid` cannot change.

### `operations/{opId}/missions/{missionId}`

`{ title, status: 'planned' | 'running' | 'complete' | 'submitted' (only complete and submitted come from R-A3; the rest Proposed), aliasIds, settings, summary?, startedAt?, endedAt?, eventRange? }`. Missions may run in parallel (D). `aliasIds` is the Handler's pick of characters for the mission (R-A6); `settings` holds only the overrides of the campaign base (R-A1, R-C1). The GM writes everything but the summary fields; every mission gets a summary ([11](11-supplemental-features.md)), written by the archive function (`summary`, `endedAt`, `eventRange`). `[U]` The `eventRange` unit across several episodes is not designed yet.

### `episodes/{episodeId}`

```json
{
  "campaignId": "string",
  "operationId": "string",
  "missionId": "string",
  "gmUid": "string",
  "memberUids": ["uid"],
  "engineMajor": 1,
  "status": "open | archived",
  "createdAt": "<timestamp>",
  "updatedAt": "<timestamp>"
}
```

- One document per episode: one event log, one RTDB live tree (`/episodes/$ep`), one local sembast file, one host. The id is the same as the RTDB key.
- `memberUids` lists the accounts admitted to this episode and always contains `gmUid`. It is a subset of the campaign's `memberUids` `[U]` (rules cannot check a subset cheaply; the GM client keeps it so).
- Created and edited by the GM while a handler; `campaignId`, `operationId`, `missionId` and `gmUid` cannot change. `status` becomes `archived` only through the archive function.

### `episodes/{episodeId}/members/{uid}`

`{ aliasId, joinedAt }`. **Canonical copy:** RTDB `members` is canonical during play and survives archive and clean-up as the locked stub (06). This document and `memberUids` are the searchable copy: the GM client writes both in one batch (the rule checks `getAfter`), and the archive function reconciles them from RTDB. Written by the GM only, while a handler. A member reads **only their own entry** and cannot list; the GM reads all (06 RTDB table). The archive chunk rule reads `aliasId` from here.

## Archives

Archives are written by a function when an episode ends, after the lock step of the archive order (lock, archive, clean-up; [06](06-accounts-backend.md)). One archive per episode.

- `archiveIndex/{episodeId}`: `{ campaignId, operationId, missionId, gmUid, memberUids, engineMajor, chunkCount, byteSize, archivedAt, formatVersion }`. Small; read by members. Fields the genesis `archives` list needs (05) are added here once the log unit's archive layout is settled (Held).
- `archives/{episodeId}/chunks/{n}`: `{ kind, audience, fromSeq, toSeq, payload, formatVersion }`.

`kind` is `frozen` (the canonical frozen log, archived as-is, 05; it holds every audience, so `audience` is `gm`), `head` (the final head snapshot, `gm`) or `textlog` (the per-perspective plain-text log, 05, one audience per chunk). `audience` is `gm`, `public` or `alias:<aliasId>`, mirroring the RTDB branches. Because rules read whole documents, every chunk has exactly one audience. The GM reads every audience (06); any member reads `public`; a member reads `alias:<id>` only for their own alias in that episode. `payload` is a JSON string sized so the whole document stays under about 800 to 900 KiB. `[U]` Exact chunk size is a tuning value, not measured against real events.

The frozen log (the canonical event stream) and the per-perspective text log are stored the same way: the text log chunks use `audience` like events. **Retention (R-A3):** once a mission is marked complete or submitted, its episodes' archives are removed except the latest snapshot; the pruning step and where that snapshot is kept are a later row.

## Library, packs and listings

### `libraryPending/{id}`, `libraryPublic/{id}` and `libraryData/{id}`

User-created content (skills, techniques, spells, items, NPC templates, packs' loose parts, later mission submissions). A mission submission carries the debrief forms and summary only, never an event log or text log (Q9, R 2026-10-27). Gated sections are **separate documents** with a data document and a summary document (11, V-48), and access is a per-tier list of levels, not "tier >= N".

`libraryPending/{id}` holds the submission whole; moderators read it, the owner reads and edits it:

```json
{
  "kind": "skill | technique | spell | item | npc | pack",
  "name": "string",
  "ownerUid": "string",
  "summaryLevel": 1,
  "dataLevel": 1,
  "status": "testing | released",
  "tags": ["string"],
  "keywords": ["lowercase", "words"],
  "summary": { },
  "data": { },
  "createdAt": "<timestamp>",
  "revokedReason": "string, only after a revocation"
}
```

On approval a moderator writes, in one batch, `libraryPublic/{id}` (`kind, name, summaryLevel, status, tags, keywords, summary, ownerUid, verifier, verifiedAt, version`) and `libraryData/{id}` (`dataLevel, status, data`), then deletes the pending document. `verifier`, `verifiedAt` and `version` are the record 06 requires. **Revocation** (06) is a moderator writing the item back to `libraryPending` with `revokedReason` and deleting the two public documents; copies already in GM packs are unchanged.

- `keywords` is the lowercased, deduplicated words of `name` and `tags`, built by the client when it writes (FS4: Standard edition has no full-text search). Search is `array-contains` on one keyword.
- Reads: a summary is readable if `summaryLevel` is in `tierLevels/{tier}.summaryLevels` (one `get`), data if `dataLevel` is in `.dataLevels`; tier 0 reads the same free level-1 entries as tier 1 (Q33, D 2026-10-22, 11), so `tierLevels/0` lists level 1 and nothing above. The app queries with `where summaryLevel in [<its levels>]` so the rule can prove it `[U]`. The contents of `tierLevels` are R's to rule (11 lists examples only). An `in` query takes at most 30 values `[U]`, which bounds the level lists.
- `status: 'testing'` is readable only by tier 5 (11, Proposed); tier 5 stays separate from the verification and `moderator` claims.
- Spells are schemaless: `data` is free-form (engine owns vocabulary, packs own values).
- The free tier is bundled in the app, so `libraryPublic` holds creator content and later additions; other content is cached after first fetch.
- Moderators (holders of the verification claim, R and D for now) approve by client write; approval is one batch.

### `packIndex/{packId}`

`{ name, version, ownerUid, engineMajor, tags, keywords, status, storagePath, visibility, updatedAt }`. The pack file itself is in Storage; the index is what is searched. `visibility` is `private` or `public`; public requires moderator approval like other public content. `status` is `testing` or `released` as for library items (11, Proposed).

### `listingsPending/{campaignId}` and `listingsPublic/{campaignId}`

Public campaigns that take join requests ([11](11-supplemental-features.md); listings live at the campaign, R-X0b): `{ name, gmUid, virtual, tags, keywords, createdAt }`, a subset of the campaign chosen by the GM. Same pending-then-public flow; only the GM of that campaign, while a handler, may submit it. Listed to signed-in full accounts (11: "listed to signed-in users").

## Security rules (draft)

Draft only, not compiled and not run `[U]`. Rules v2; helper functions first. Deny by default: nothing below matches unlisted paths.

```
rules_version = '2';
service cloud.firestore {
  match /databases/{database}/documents {

    function signedIn()   { return request.auth != null; }
    function uid()        { return request.auth.uid; }
    function isAnon()     { return request.auth.token.firebase.sign_in_provider == 'anonymous'; }
    function isFull()     { return signedIn() && !isAnon(); }
    function tier()       { return request.auth.token.get('tier', 0); }
    function isHandler()  { return isFull() && tier() >= 4; }
    // R and D hold the verification claim; 'moderator' is assigned later (11). Not 'admin'.
    function isModerator(){ return isFull() && (request.auth.token.get('arbiter', false) == true
                                                || request.auth.token.get('moderator', false) == true); }
    function pageOk()     { return request.query.limit <= 50; }
    function changes(fields) {
      return request.resource.data.diff(resource.data).affectedKeys().hasAny(fields);
    }
    function doc(path)    { return get(/databases/$(database)/documents/$(path)); }
    function campaignGm(c)   { return doc('campaigns/' + c).data.gmUid; }
    function gmOfCampaign(c) { return isHandler() && campaignGm(c) == uid(); }
    function episodeGm(ep)   { return doc('episodes/' + ep).data.gmUid; }
    function gmOfEpisode(ep) { return isHandler() && episodeGm(ep) == uid(); }
    function myBadge()    { return doc('agents/' + uid()).data.badgeNumber; }
    function levels()     { return doc('tierLevels/' + string(tier())).data; }
    function visibleStatus(status) { return status == 'released' || tier() >= 5; }
    // a missing field passes, so a document without the optional array can still be written
    function capped(field, n) { return !(field in request.resource.data) || request.resource.data[field].size() <= n; }

    match /tierLevels/{t} {
      allow get: if signedIn();                 // written in the console only
    }

    match /agents/{id} {
      allow get: if isFull() && id == uid();
      allow update: if isFull() && id == uid()
        && request.resource.data.keys().hasOnly(
             ['badgeNumber','createdAt','ageBracket','occupation','creator','gender','private'])
        && !changes(['badgeNumber', 'createdAt', 'ageBracket']);
      // create and delete: the createAgent function (Admin SDK bypasses rules)
    }

    match /profilesPublic/{badge} {
      allow get: if true;                       // redacted public page (Proposed: unauthenticated get, signed-in list)
      allow list: if isFull() && pageOk();
      allow create, update: if isModerator() && !existsAfter(/databases/$(database)/documents/profilesPending/$(badge));
      allow delete: if isModerator();
    }
    match /profilesPending/{badge} {
      allow get: if isFull() && (badge == myBadge() || isModerator());
      allow list: if isModerator() && pageOk();
      allow create, update: if isFull() && badge == myBadge()
        && request.resource.data.keys().hasOnly(['badgeNumber','fiction','private','submittedAt','updatedAt'])
        && request.resource.data.badgeNumber == badge;
      allow delete: if isModerator() || (isFull() && badge == myBadge());
    }

    match /badgeNumbers/{n}  { allow read, write: if false; }
    match /signInCodes/{c}   { allow read, write: if false; }

    match /aliases/{owner}/items/{key} {
      allow get: if signedIn() && owner == uid();
      allow list: if signedIn() && owner == uid() && pageOk();
      // anonymous: one fixed-key document, only if absent
      allow create: if signedIn() && owner == uid()
        && request.resource.data.keys().hasOnly(
             ['aliasId','private','name','fiction','summary','packPin','sheetRef','tags','createdAt','updatedAt'])
        && request.resource.data.aliasId is string && request.resource.data.aliasId.size() >= 20
        && capped('tags', 10)
        && (isFull() || (key == 'anon'
            && !exists(/databases/$(database)/documents/aliases/$(owner)/items/anon)));
      allow update: if signedIn() && owner == uid()
        && request.resource.data.keys().hasOnly(
             ['aliasId','private','name','fiction','summary','packPin','sheetRef','tags','createdAt','updatedAt'])
        && !changes(['aliasId']) && capped('tags', 10);
      allow delete: if signedIn() && owner == uid();
    }

    match /campaigns/{c} {
      allow get: if signedIn() && uid() in resource.data.memberUids;
      // [U] each query proves one branch: memberUids array-contains, or gmUid ==
      allow list: if signedIn() && pageOk()
        && (uid() in resource.data.memberUids || resource.data.gmUid == uid());
      allow create: if isHandler()
        && request.resource.data.gmUid == uid()
        && request.resource.data.memberUids == [uid()]
        && request.resource.data.status == 'open'
        && request.resource.data.keys().hasOnly(['name','gmUid','memberUids','packPins','settings','status','visibility','virtual','createdAt','updatedAt'])
        && capped('packPins', 5);
      allow update: if isHandler() && resource.data.gmUid == uid()
        && request.resource.data.gmUid == resource.data.gmUid
        && request.resource.data.keys().hasOnly(['name','gmUid','memberUids','packPins','settings','status','visibility','virtual','createdAt','updatedAt'])
        && resource.data.gmUid in request.resource.data.memberUids   // the GM cannot drop out
        && capped('memberUids', 20) && capped('packPins', 5)
        && resource.data.status != 'archived'
        && request.resource.data.status != 'archived';              // admin SDK only
      // delete: function only

      match /members/{m} {
        allow get: if signedIn() && (uid() == m || campaignGm(c) == uid());   // anonymous members read their own entry
        allow list: if gmOfCampaign(c) && pageOk();
        // the GM writes this document and memberUids in one batch
        allow create: if gmOfCampaign(c)
          && request.resource.data.keys().hasOnly(['joinedAt'])
          && m in getAfter(/databases/$(database)/documents/campaigns/$(c)).data.memberUids;
        allow update: if gmOfCampaign(c) && request.resource.data.keys().hasOnly(['joinedAt']);
        allow delete: if gmOfCampaign(c)
          && !(m in getAfter(/databases/$(database)/documents/campaigns/$(c)).data.memberUids);
      }
      match /invites/{t} {
        allow get: if gmOfCampaign(c);
        allow list: if gmOfCampaign(c) && pageOk();
        allow create, update: if gmOfCampaign(c)
          && request.resource.data.keys().hasOnly(['createdBy','expiresAt','maxUses','uses','aliasHint']);
        allow delete: if gmOfCampaign(c);
      }
      match /joinRequests/{r} {
        // public campaigns only from clients; invites write here through the function
        allow create: if signedIn() && r == uid()
          && request.resource.data.keys().hasOnly(['aliasId','aliasKey','message','status','createdAt'])
          && request.resource.data.status == 'open'
          && doc('aliases/' + uid() + '/items/' + request.resource.data.aliasKey).data.aliasId == request.resource.data.aliasId
          && ('message' in request.resource.data ? isFull() : true)   // tier 0 cannot message
          && doc('campaigns/' + c).data.visibility == 'public'
          && doc('campaigns/' + c).data.status == 'open';
        allow get: if gmOfCampaign(c);
        allow list: if gmOfCampaign(c) && pageOk();
        allow update: if gmOfCampaign(c) && request.resource.data.keys().hasOnly(['aliasId','aliasKey','message','status','createdAt'])
          && !changes(['aliasId','aliasKey','message','createdAt']);
        allow delete: if gmOfCampaign(c);
      }
      match /transfers/{t} {
        allow create: if isFull() && request.resource.data.fromUid == uid()
          && request.resource.data.keys().hasOnly(['fromUid','aliasId','aliasKey','sourceCampaignId','status','createdAt'])
          && request.resource.data.status == 'offered'
          && doc('aliases/' + uid() + '/items/' + request.resource.data.aliasKey).data.aliasId == request.resource.data.aliasId;   // aliasKey = alias document key; binds the claimed id to the caller's own alias
        allow get: if isFull() && (resource.data.fromUid == uid() || campaignGm(c) == uid());
        allow list: if gmOfCampaign(c) && pageOk();
        allow update: if gmOfCampaign(c)
          && resource.data.status == 'offered'
          && request.resource.data.keys().hasOnly(['fromUid','aliasId','aliasKey','sourceCampaignId','status','createdAt'])
          && request.resource.data.status in ['accepted', 'declined']
          && !changes(['fromUid', 'aliasId', 'aliasKey', 'sourceCampaignId', 'createdAt']);
      }
    }

    match /operations/{op} {
      // read by campaign membership: one lookup
      allow get: if signedIn() && uid() in doc('campaigns/' + resource.data.campaignId).data.memberUids;
      allow list: if signedIn() && pageOk()
        && uid() in doc('campaigns/' + resource.data.campaignId).data.memberUids;   // [U] queries filter campaignId ==
      allow create: if isHandler() && request.resource.data.gmUid == uid()
        && campaignGm(request.resource.data.campaignId) == uid()
        && request.resource.data.keys().hasOnly(['campaignId','gmUid','name','status','order','createdAt','updatedAt']);
      allow update: if isHandler() && resource.data.gmUid == uid()
        && request.resource.data.keys().hasOnly(['campaignId','gmUid','name','status','order','createdAt','updatedAt'])
        && !changes(['campaignId', 'gmUid', 'createdAt']);

      match /missions/{mi} {
        allow get, list: if signedIn()
          && uid() in doc('campaigns/' + doc('operations/' + op).data.campaignId).data.memberUids;
        // the GM plans missions; the archive function writes summary, endedAt and eventRange
        allow create: if isHandler() && doc('operations/' + op).data.gmUid == uid()
          && request.resource.data.keys().hasOnly(['title','status','aliasIds','settings','startedAt'])
          && capped('aliasIds', 20);
        allow update: if isHandler() && doc('operations/' + op).data.gmUid == uid()
          && request.resource.data.keys().hasOnly(['title','status','aliasIds','settings','summary',
               'startedAt','endedAt','eventRange'])
          && !changes(['summary', 'endedAt', 'eventRange'])
          && capped('aliasIds', 20);
      }
    }

    match /episodes/{ep} {
      allow get: if signedIn() && uid() in resource.data.memberUids;
      allow list: if signedIn() && pageOk() && uid() in resource.data.memberUids;
      allow create: if isHandler()
        && request.resource.data.gmUid == uid()
        && campaignGm(request.resource.data.campaignId) == uid()
        // the operation and mission must belong to that campaign
        && doc('operations/' + request.resource.data.operationId).data.campaignId == request.resource.data.campaignId
        && exists(/databases/$(database)/documents/operations/$(request.resource.data.operationId)/missions/$(request.resource.data.missionId))
        && request.resource.data.keys().hasOnly(['campaignId','operationId','missionId','gmUid','memberUids',
             'engineMajor','status','createdAt','updatedAt'])
        && request.resource.data.memberUids == [uid()]
        && request.resource.data.status == 'open';
      allow update: if isHandler() && resource.data.gmUid == uid()
        && request.resource.data.keys().hasOnly(['campaignId','operationId','missionId','gmUid','memberUids',
             'engineMajor','status','createdAt','updatedAt'])
        && !changes(['campaignId', 'operationId', 'missionId', 'gmUid', 'createdAt'])
        && resource.data.gmUid in request.resource.data.memberUids   // the GM cannot drop out
        && capped('memberUids', 20)
        && resource.data.status != 'archived'
        && request.resource.data.status != 'archived';              // admin SDK only
      // delete: function only (R-A3 pruning)

      match /members/{m} {
        allow get: if signedIn() && (uid() == m || episodeGm(ep) == uid());
        allow list: if gmOfEpisode(ep) && pageOk();
        // RTDB members is canonical; the GM writes this copy and memberUids in one batch
        allow create: if gmOfEpisode(ep)
          && request.resource.data.keys().hasOnly(['aliasId','joinedAt'])
          && m in getAfter(/databases/$(database)/documents/episodes/$(ep)).data.memberUids;
        // frozen once archived: the archive chunk rule reads aliasId from here
        allow update: if gmOfEpisode(ep) && doc('episodes/' + ep).data.status != 'archived'
          && request.resource.data.keys().hasOnly(['aliasId','joinedAt']);
        allow delete: if gmOfEpisode(ep)
          && !(m in getAfter(/databases/$(database)/documents/episodes/$(ep)).data.memberUids);
      }
    }

    match /archiveIndex/{ep} {
      allow get: if signedIn() && uid() in resource.data.memberUids;
      allow list: if signedIn() && pageOk() && uid() in resource.data.memberUids;
    }
    match /archives/{ep}/chunks/{n} {
      // audience is stored in the chunk, so the rule needs no lookup to read it
      allow get: if signedIn() && (
        doc('archiveIndex/' + ep).data.gmUid == uid()                         // GM reads every audience
        || (resource.data.audience == 'public'
            && uid() in doc('archiveIndex/' + ep).data.memberUids)
        || (resource.data.audience.matches('alias:.*')
            && resource.data.audience == 'alias:'
               + doc('episodes/' + ep + '/members/' + uid()).data.aliasId));
      allow list: if false;  // clients fetch by id from archiveIndex.chunkCount
    }

    match /libraryPending/{id} {
      allow get: if isFull() && (resource.data.ownerUid == uid() || isModerator());
      allow list: if isFull() && pageOk() && (isModerator() || resource.data.ownerUid == uid());
      allow create: if isFull()
        && request.resource.data.keys().hasOnly(['kind','name','ownerUid','summaryLevel','dataLevel',
             'status','tags','keywords','summary','data','createdAt','revokedReason'])
        && capped('tags', 10) && capped('keywords', 30)
        && (isModerator() || request.resource.data.ownerUid == uid());   // moderator: revocation
      allow update: if isFull() && resource.data.ownerUid == uid()
        && request.resource.data.ownerUid == uid()
        && request.resource.data.keys().hasOnly(['kind','name','ownerUid','summaryLevel','dataLevel',
             'status','tags','keywords','summary','data','createdAt','revokedReason'])
        && capped('tags', 10) && capped('keywords', 30);
      allow delete: if isFull() && (resource.data.ownerUid == uid() || isModerator());
    }
    match /libraryPublic/{id} {
      allow get: if signedIn() && resource.data.summaryLevel in levels().summaryLevels
        && visibleStatus(resource.data.status);
      allow list: if signedIn() && pageOk() && resource.data.summaryLevel in levels().summaryLevels
        && visibleStatus(resource.data.status);
      allow create, update: if isModerator() && !existsAfter(/databases/$(database)/documents/libraryPending/$(id));
      allow delete: if isModerator();
    }
    match /libraryData/{id} {
      allow get: if signedIn() && resource.data.dataLevel in levels().dataLevels
        && visibleStatus(resource.data.status);
      allow list: if false;
      allow create, update: if isModerator();
      allow delete: if isModerator();
    }

    match /packIndex/{id} {
      allow get: if signedIn() && (resource.data.ownerUid == uid()
        || (resource.data.visibility == 'public' && visibleStatus(resource.data.status)));
      allow list: if signedIn() && pageOk() && (resource.data.ownerUid == uid()
        || (resource.data.visibility == 'public' && visibleStatus(resource.data.status)));
      allow create: if isFull() && request.resource.data.ownerUid == uid()
        && request.resource.data.keys().hasOnly(['name','version','ownerUid','engineMajor','tags','keywords',
             'status','storagePath','visibility','updatedAt'])
        && capped('tags', 10) && capped('keywords', 30)
        && (request.resource.data.visibility == 'private' || isModerator());
      allow update: if isFull()
        && request.resource.data.keys().hasOnly(['name','version','ownerUid','engineMajor','tags','keywords',
             'status','storagePath','visibility','updatedAt'])
        && capped('tags', 10) && capped('keywords', 30)
        && (isModerator()
            || (resource.data.ownerUid == uid() && request.resource.data.ownerUid == uid()
                && request.resource.data.visibility == 'private'));
      allow delete: if isFull() && (resource.data.ownerUid == uid() || isModerator());
    }

    match /listingsPublic/{c} {
      allow get: if isFull();
      allow list: if isFull() && pageOk();
      allow create, update: if isModerator() && !existsAfter(/databases/$(database)/documents/listingsPending/$(c));
      allow delete: if isModerator();
    }
    match /listingsPending/{c} {
      allow get: if isFull() && (resource.data.gmUid == uid() || isModerator());
      allow list: if isFull() && pageOk() && (isModerator() || resource.data.gmUid == uid());
      allow create, update: if gmOfCampaign(c) && request.resource.data.gmUid == uid()
        && doc('campaigns/' + c).data.visibility == 'public'
        && request.resource.data.keys().hasOnly(['name','gmUid','virtual','tags','keywords','createdAt'])
        && capped('tags', 10) && capped('keywords', 30);
      allow delete: if gmOfCampaign(c) || isModerator();
    }
  }
}
```

Notes on the draft:

- `profilesPublic` `get: if true` lets an unauthenticated browser read the public page by badge number; enumeration (`list`) needs sign-in. Proposed: yes, because the Hosting page is for people without the app (11), and it is safe only because the document holds the redacted, approved form.
- A `list` rule that tests `resource.data` only passes when the query itself constrains the same field (for example `where memberUids array-contains uid`). Firestore refuses a list the rule cannot prove from the query. Each query in the next section is written to satisfy its rule `[U]`.
- A `get` that errors inside `||` (for example a missing member document in the archive chunk rule) is treated as false for that branch `[U]`; test it.
- Lookups per request: archive chunk 3, episode create 4 (campaign, operation, mission, plus `getAfter` on member writes elsewhere), mission 2 (operation, then campaign), campaign and episode subcollections 1 to 2, `profilesPending` 1; all inside the 10 cap [V-7].

## Queries and composite indexes

Every query the app runs, so a `FAILED_PRECONDITION` [V-43] is a deploy error and not a surprise. Single-field indexes are automatic and not listed. Library and pack queries below also filter `status == 'released'` (callers below tier 5 cannot read `testing` entries, and a list rule passes only if the query proves it). Equality and `in` filters come before the order-by fields in these indexes `[U]` (confirm each in the emulator).

| Query | Index |
|---|---|
| Library browse: `kind ==`, `summaryLevel in [...]`, order `summaryLevel, name` | `libraryPublic`: `status ASC, kind ASC, summaryLevel ASC, name ASC` |
| Library keyword search: `keywords array-contains`, `summaryLevel in [...]`, order `summaryLevel, name` | `libraryPublic`: `keywords ARRAY_CONTAINS, status ASC, summaryLevel ASC, name ASC` |
| Library tag filter, same shape | `libraryPublic`: `tags ARRAY_CONTAINS, status ASC, summaryLevel ASC, name ASC` |
| My pending submissions | `libraryPending`: `ownerUid ASC, createdAt DESC` |
| Moderation queues | single field `createdAt` on `libraryPending`, `profilesPending`, `listingsPending` |
| Campaigns I GM | `campaigns`: `gmUid ASC, createdAt DESC` |
| Campaigns I am in | `campaigns`: `memberUids ARRAY_CONTAINS, createdAt DESC` |
| Operations of a campaign | `operations`: `campaignId ASC, order ASC` |
| Episodes of a mission | `episodes`: `missionId ASC, memberUids ARRAY_CONTAINS, createdAt ASC` `[U]` (the list rule needs the `memberUids` filter) |
| Episodes I am in | `episodes`: `memberUids ARRAY_CONTAINS, createdAt DESC` |
| Public campaigns by tag or keyword | `listingsPublic`: `tags ARRAY_CONTAINS, createdAt DESC` and `keywords ARRAY_CONTAINS, createdAt DESC` |
| Transfer requests for my campaign | none (subcollection, filter `status ==` on one field) |
| Packs by keyword or tag | `packIndex`: `visibility ASC, status ASC, keywords ARRAY_CONTAINS, name ASC` and `visibility ASC, status ASC, tags ARRAY_CONTAINS, name ASC` |
| My packs | `packIndex`: `ownerUid ASC, name ASC` |
| Archives I am in | `archiveIndex`: `memberUids ARRAY_CONTAINS, archivedAt DESC` |
| Missions of an operation | none (subcollection, ordered by `startedAt`) |

Deployed as `firebase/firestore.indexes.json` and `firebase/firestore.rules` when built. `[U]` None of these indexes has been created or queried; only the missing-index error behaviour is verified [V-43]. Searching archived missions by keyword (FS4) needs keyword fields on `missions` or `archiveIndex` and is **Held** with X0.

## Test plan (Emulator Suite)

Not run. When built, mirror `firebase/rtdb_rules_test/`. Seed `tierLevels/0` to `/5`; tier 0 lists level 1 only (Q33). A missing document makes every level read fail closed.

1. Anonymous account: creates `aliases/<uid>/items/anon` once; second create refused; other keys refused; cannot read `agents`, create `campaigns`, `operations` or `episodes`, or read `libraryData` above level 1 (level-1 entries are readable); can create a `joinRequests` document without `message` on a public campaign, and is refused with `message`.
2. Alias ids: a join request or transfer carrying another player's `aliasId` is refused; two anonymous accounts both keyed `anon` have different `aliasId` fields; an alias update cannot change `aliasId`; (host-level) admission of a duplicate `aliasId` is refused.
3. Tier gates: tier 3 cannot create a campaign, operation or episode; tier 4 can. A lapsed handler (claim back to 3) cannot update the campaign, operation, mission or episode, write `members`, create an `invites` document or submit a `listingsPending` document, but can still read the campaign, operations, missions, episodes and archives (invites and join requests are GM-handler only).
4. Owner isolation and whitelists: `agents` and `aliases` readable only by the owner; `ageBracket` and `badgeNumber` not editable; an extra key (for example `email`) is refused on `agents`, `aliases`, `campaigns`, `episodes`, `profilesPending`, `joinRequests`, `transfers` (create and update), `listingsPending`, `packIndex`, `libraryPending`; `badgeNumbers` and `signInCodes` refused for everyone.
5. Campaign and episode membership: non-member `get` and `list` refused on campaigns, operations, missions and episodes; an operation or episode cannot be created under another GM's campaign; `campaignId`, `operationId` and `missionId` cannot change; the GM cannot write mission summary fields; an episode naming another campaign's operation, or a mission that does not exist, is refused; a member lists the operations of their campaign with `campaignId ==` and the same query without that filter is refused; `gmUid` change refused; the GM cannot remove themself from `memberUids`; a client cannot set `status: 'archived'`; a player cannot add themselves; a `members` create without the matching `memberUids` entry is refused; a member reads only their own `members` entry; a requester cannot read their request; a join request on an archived or private campaign is refused; the GM can delete an invite; array caps refused above 20 / 10 / 30 / 5.
6. Listings: a full account cannot submit a `listingsPending` document for a campaign it does not run.
7. Archive audiences: GM reads all three audience kinds; an episode member reads `public` and only their own `alias:<aliasId>`; a campaign member who was not in the episode reads nothing; after the archive the GM cannot change a member's `aliasId`; `list` refused; a missing member document gives a refusal, not an error.
8. Library levels: with `tierLevels` `summaryLevels: [1,2]` a caller reads level 1-2 summaries and not level 3; `libraryData` follows `dataLevels`; `testing` items only for tier 5; owner cannot write `libraryPublic`; a holder of `arbiter` or `moderator` can, and `admin` alone cannot; the public create is refused while the pending document still exists; revocation back to pending works.
9. Pending then public for profiles, listings and packs; a non-moderator cannot make a pack `public`; pack delete works for owner and moderator.
10. Transfers: only the alias owner creates (`aliasKey` must name the caller's own alias document and its `aliasId` field must equal the claimed `aliasId`; a forged `aliasId` is refused), only the destination GM (a handler) decides, a decided request cannot be flipped.
11. Pagination: list queries without `limit`, or with `limit > 50`, refused [V-49].
12. Queries: each query in the index table run against emulator indexes, and one without its index returns `FAILED_PRECONDITION`.
13. Claim refresh: tier change visible only after a forced token refresh [V-42][V-43].

## Held and questions for R

**Held:** the archive layout per mission, the genesis `archives` fields and `missions.eventRange` unit across several episodes; carrying alias state between missions; the public profile's alias, operation and mission lists; the Handler persona document (R-A4, later row); the R-A3 pruning step; mission submissions as a library kind with summary and clearance level, the archive pending/public pair and news (06, 11); the feedback collection (write-only for users, admins read; 11, Proposed); the consent opt-in storage (11); Storage rules for profile images and pack files; the contents of `tierLevels` (R to rule).

**Proposed answers, for R to confirm together** (each follows an existing ruling where one is named):

1. **Moderation by client write** under rules, extending the B3 and Library ruling in 06; a function only if the rules get awkward. Approval is one batch (write public, delete pending, checked with `existsAfter`).
2. **Claims as ruled:** the verification claim (R and D) and a later `moderator` claim; no merge, `admin` is not used. The verification claim's token key is `arbiter` (R, 2026-10-21).
3. **One `createAgent` function** issues the badge number and creates `agents/{uid}` (implied by 11, badge numbers).
4. **`tierLevels/{tier}` lookup document** for what each tier may read, instead of level claims: one `get`, and R and D change it without re-issuing claims.
5. **Unauthenticated `get` on `profilesPublic/{badge}`**, redacted fields only; `list` stays signed-in.
6. **Provisional array caps** (R sets the numbers): `memberUids` 20, `tags` 10, `keywords` 30, `packPins` 5.
7. **Transfer-move function** for the move and clean-up only: transactional, checks the source episode's RTDB `meta` with admin REST (no live host), moves the alias, notifies the source GM's inbox. The approval itself is a rules-checked client write.
8. **`signInCodes` TTL** as clean-up only. The function checks expiry in a transaction.
9. **Where the campaign document lives. Ruled by R, 2026-11-03: option A, top-level `campaigns/{campaignId}`.** R-A1 and R-A6 move pack pins, base settings, join links, the roster and listings to the campaign, so they need a home. Options:
   - **A (recommended): top-level `campaigns/{campaignId}`,** with `operations`, `episodes`, `archiveIndex` and listings as top-level collections that carry `campaignId` (and `operationId`, `missionId`) as fields. Ids stay short and match the RTDB key, "episodes I am in" and "campaigns I am in" are plain single-collection queries, and an alias transfer or a mission move never changes a document path. Cost: rules that need the campaign do one `get` (missions do two), well inside the 10 cap.
   - **B: nested `campaigns/{c}/operations/{op}/missions/{mi}/episodes/{ep}`.** Rules read parent ids from the path with no lookup, and a campaign's whole tree sits under one prefix. Cost: "episodes I am in" across campaigns needs a collection-group query, its own index and `{path=**}` rules; archive and RTDB ids no longer match one flat key; deep paths in every client call.
   - Variant of A (information): nest `operations/{op}/missions/{mi}` under `campaigns/{c}` and keep `campaigns`, `episodes`, `archiveIndex` and listings top-level. Operations are only listed per campaign and their ids are not RTDB keys, so nothing is lost, the operations `list` rule needs no `[U]` query proof, and mission rules save a lookup.
   - **C: campaign fields on the old `operations/{opId}` document** (no new collection). Fewest changes now, but it reintroduces the mixing R ruled against and gives campaign data no home once a campaign has several operations.

