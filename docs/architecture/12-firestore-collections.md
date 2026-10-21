# 12. Firestore collections (P10c)

Status: **Proposed**, awaiting R. Nothing here is built. The rules and indexes below have **not** been run in the Emulator Suite; every behaviour claim that depends on that is marked `[U]` (unverified). Verified facts carry their V-id.

This chapter fills the gap left by [06](06-accounts-backend.md) (FS1 to FS5 chose Firestore for data at rest and a hand-written REST client on desktop). It names the collections, the document shapes, the security rules and the composite indexes. Account fields come from [11](11-supplemental-features.md). Archive layout follows [05](05-migrator.md). Anything that depends on the unresolved event-log unit (X0) is held and listed at the end.

## Constraints that shape the design

| Constraint | Consequence | Source |
|---|---|---|
| Rules read whole documents; a field cannot be hidden from a reader who may read the document. | Anything with a different audience is a separate document. | [V-48] |
| At most 10 `get`/`exists` per request. | Rules use claims first and at most three lookups per path. | [V-7] |
| 1 MiB document cap. | Archives are chunked at about 800 to 900 KiB. | [V-33] |
| Page size can be capped in rules with `request.query.limit`. | Every `list` rule below calls `pageOk()`. | [V-49] |
| Desktop has no live listeners; REST with `getIdToken()` on every request. | Collections are read by query or by id, never by subscription. Freshness comes from refetch. | [V-47] |
| `FAILED_PRECONDITION` means a missing composite index. | Every query the app runs is in the index list below. | [V-43] |
| Claim-based rules work after a forced token refresh. | `tier`, `admin`, `moderator` claims are read from the token. A tier change takes effect after a forced token refresh (a plain refresh did not pick it up [V-42]). | [V-43] |
| Standard edition: no full-text search. | Keyword and tag arrays, queried with `array-contains`. | FS4 |
| Dart functions have no Firestore triggers. | Function work is HTTPS-only; clients call it explicitly. | [V-23] |
| Archives are written by a function with `firebase_admin_sdk`. | Clients never write archive documents. | FS3 |

Claims used by rules (set by functions only; the claim is the only copy of the tier): `tier` (0 to 5), `dataLevels` and `summaryLevels` (the entry levels 1-4 the tier may read; 11 "Per-tier lookup", Proposed as claims), `admin` (R and D), `moderator`. Anonymous accounts are tier 0 and have `firebase.sign_in_provider == 'anonymous'`.

## Collections at a glance

| Collection | Document id | Audience | Written by |
|---|---|---|---|
| `agents/{uid}` | account uid | owner (private fields) | owner, function at creation |
| `profilesPublic/{badge}` | badge number (never the uid) | anyone (public page) | moderator, after approval of `profilesPending` |
| `profilesPending/{badge}` | badge number | owner, moderators | owner; deleted on approval |
| `badgeNumbers/{n}` | 16-digit badge number | function only | function |
| `signInCodes/{code}` | single-use code | function only | function |
| `aliases/{uid}/items/{aliasId}` | generated id; `anon` for tier 0 | owner | owner |
| `operations/{opId}` | operation id | GM, members | GM |
| `operations/{opId}/members/{uid}` | account uid | the member (own entry), GM | GM |
| `operations/{opId}/invites/{token}` | invite token | GM | GM |
| `operations/{opId}/requests/{uid}` | requester uid | GM only | requester creates; GM updates |
| `operations/{opId}/transfers/{id}` | generated id | GM (destination), requester | alias owner creates; GM decides |
| `operations/{opId}/missions/{missionId}` | mission id | members | function (archive) |
| `archives/{opId}/chunks/{n}` | chunk number | members, per audience | function only |
| `archiveIndex/{opId}` | operation id | members | function |
| `libraryPending/{id}` | content id | owner, moderators | owner; moderator (revocation) |
| `libraryPublic/{id}` | content id | summary levels per tier | moderator |
| `libraryData/{id}` | content id | data levels per tier | moderator |
| `packIndex/{packId}` | pack id | signed-in (public packs), owner | pack owner; moderator for public |
| `listingsPublic/{opId}` | operation id | signed-in full accounts | moderator, after approval |
| `listingsPending/{opId}` | operation id | GM, moderators | GM |

Names follow the library's "pending then public" model ([11](11-supplemental-features.md)). Pending and public are separate collections, not a status field, so that a public query never has to filter out unapproved content and a rule cannot be fooled by a status edit.

## Accounts

### `agents/{uid}` (private)

Owner-only real and account data. Created by a function when an account becomes a full account (first full sign-in or upgrade). Tier 0 (anonymous) accounts have **no** `agents` document, no profile and no badge ([11](11-supplemental-features.md)).

```json
{
  "badgeNumber": "0000000000000013",
  "createdAt": "<timestamp>",
  "ageBracket": "26-35",
  "occupation": "string",
  "creator": false,
  "gender": "string"
}
```

- Real data is section 10 only: age bracket, occupation, creator flag, gender. **Email stays in Firebase Auth** and is not copied here (11). Payment data is never in Firestore. The tier lives only in the claim.
- `badgeNumber` and `createdAt` are written by a function (a client cannot pick its own badge). `ageBracket` is set at account creation (age verification happens then, 06) and is not owner-editable; the owner may edit `occupation`, `creator`, `gender`.
- `ageBracket` is one of `under 12`, `12-17`, `18-25`, `26-35`, `36-45`, `46-55`, `56+`.

### `profilesPublic/{badge}` (fiction, public)

The in-world profile page (served by Hosting; [11](11-supplemental-features.md)). The document id is the **badge number**, and the document carries no uid: the public badge payload is keyed by badge number and never exposes the Auth uid (11). Fictional fields only; nothing here is real personal data. Ownership is proven in rules by the `agents` document (`badgeNumber` of the caller).

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

Public content is moderator-approved first, so an edit goes to `profilesPending/{badge}` (same shape plus `submittedAt`) and a moderator writes it into `profilesPublic` and deletes the pending document in one batched commit (a batch is atomic). A function-based approval is the alternative if R prefers (see questions).

### `badgeNumbers/{n}` and `signInCodes/{code}` (function only)

- `badgeNumbers/{n}`: `{ uid, issuedAt }`. Lets the companion scan resolve a badge to an account. Clients cannot read or write it; a function resolves a scan and returns only what the scanner may see. Numbers 0 to 99 are hand-assigned (D is `0000000000000013`). The number is a keyed permutation computed in a function, so it is not derivable from the uid.
- `signInCodes/{code}`: `{ uid, expiresAt, used }`. Single use, issued by a function. A TTL policy on `expiresAt` removes stale codes. `[U]` TTL policy not tested.

## Aliases (characters)

`aliases/{uid}/items/{aliasId}` is private to the owner (11: these fields are owner-only documents, never indexed for search).

```json
{
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

The alias sheet and play state (inventory, skills, contacts) are engine components, not fields of this document; they live in the GM's store during play and in the archive afterwards ([05](05-migrator.md)). Carrying a character's state between missions waits on Q24 and X0.

## Operations

### `operations/{opId}`

```json
{
  "name": "string",
  "gmUid": "string",
  "memberUids": ["uid"],
  "engineMajor": 1,
  "packPins": [{ "packId": "string", "version": "string" }],
  "status": "open | archived",
  "visibility": "private | public",
  "virtual": false,
  "createdAt": "<timestamp>",
  "updatedAt": "<timestamp>"
}
```

- `memberUids` is a denormalised copy of the member documents. It exists so that "operations I am in" is one indexed query and so rules can test membership with `request.auth.uid in resource.data.memberUids` without a `get` (saves a read against the 10-lookup cap).
- Only the GM creates and edits the document. `gmUid` cannot change after creation. `status` becomes `archived` only through the archive function (admin SDK); rules refuse a client write of `archived`, matching the RTDB ruling (06). `virtual` means played online (11). Handler tier (4) is required to create an operation; lapsed handlers keep read and archive access only ([11](11-supplemental-features.md)).
- Writing `memberUids` is allowed to the GM only; joins go through the GM (invite or request approval), never a self-add.

### `operations/{opId}/members/{uid}`

`{ aliasId, joinedAt, role: 'gm' | 'player' }`. Mirrors the RTDB `members` branch (the RTDB copy is what live play reads; the Firestore copy survives archive and clean-up). Written by the GM only. A member reads **only their own entry** and cannot list; the GM reads all (06 RTDB table).

### `operations/{opId}/invites/{token}`

`{ createdBy, expiresAt, maxUses, uses, aliasHint? }`. The token is the document id and also the deep link `bard://join/<opId>?invite=<token>`. Only the GM reads and writes the collection; a joiner presents the token to a function that validates it and adds the member (a client cannot read the collection to check a token it does not own). `[U]` The join function is not specified yet.

### `operations/{opId}/requests/{uid}`

Join request for a public operation (11): `{ aliasId, message, status: 'open', createdAt }`. Any signed-in account, anonymous included (06: anonymous can join any session), creates one document keyed by their own uid, and only on an operation whose `visibility` is `public`. The requester cannot read it back (matches RTDB); the GM reads, updates `status`, and deletes. The permitted field set is held until request kinds are defined (open item from the RTDB review).

### `operations/{opId}/transfers/{id}`

Alias transfer request (concern 4, Fixed): `{ fromUid, aliasId, sourceOpId, status: 'offered' | 'accepted' | 'declined', createdAt }`, a document under the **destination** operation, approvable only by its GM. The source operation is notified (a function writes to the source GM's inbox) and does not consent. An alias in a running operation cannot move until that operation ends, which rules cannot check, so a function performs the move on an accepted request and refuses a running source `[U]`.

### `operations/{opId}/missions/{missionId}`

Every mission gets a summary ([11](11-supplemental-features.md)): `{ title, summary, startedAt, endedAt, eventRange: { fromSeq, toSeq } }`, written by the archive function. The `eventRange` unit depends on X0 and is therefore Proposed.

## Archives

Archives are written by a function at the end of a mission, after the lock step of the archive order (lock, archive, clean-up; [06](06-accounts-backend.md)).

- `archiveIndex/{opId}`: `{ gmUid, memberUids, engineMajor, chunkCount, byteSize, archivedAt, formatVersion }`. Small; read by members. Fields the genesis `archives` list needs (05) are added here once X0 fixes the log unit (Held).
- `archives/{opId}/chunks/{n}`: `{ kind, audience, fromSeq, toSeq, payload, formatVersion }`.

`kind` is `frozen` (the canonical frozen log, archived as-is, 05; it holds every audience, so `audience` is `gm`), `head` (the final head snapshot, `gm`) or `textlog` (the per-perspective plain-text log, 05, one audience per chunk). `audience` is `gm`, `public` or `alias:<aliasId>`, mirroring the RTDB branches. Because rules read whole documents, every chunk has exactly one audience (Proposed; the layout per mission is Held on X0). The GM reads every audience (06); any member reads `public`; a member reads `alias:<id>` only for their own alias. `payload` is a JSON string sized so the whole document stays under about 800 to 900 KiB. `[U]` Exact chunk size is a tuning value, not measured against real events.

The frozen log (the canonical event stream) and the per-perspective text log are stored the same way: the text log chunks use `audience` like events. How the two streams are laid out per mission is held on X0.

## Library, packs and listings

### `libraryPending/{id}`, `libraryPublic/{id}` and `libraryData/{id}`

User-created content (skills, techniques, spells, items, NPC templates, packs' loose parts, later mission submissions). Gated sections are **separate documents** with a data document and a summary document (11, V-48), and access is a per-tier list of levels, not "tier >= N".

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
- Reads: a summary is readable if `summaryLevel` is in the caller's `summaryLevels` claim, data if `dataLevel` is in `dataLevels`; tier 0 has no data access (11). The app queries with `where summaryLevel in [<its levels>]` so the rule can prove it `[U]`. The tier-to-levels map is R's to rule (11 lists examples only).
- `status: 'testing'` is readable only by tier 5 (11, Proposed); tier 5 stays separate from `admin`.
- Spells are schemaless: `data` is free-form (engine owns vocabulary, packs own values).
- The free tier is bundled in the app, so `libraryPublic` holds creator content and later additions; other content is cached after first fetch.
- Moderators (R and D for now) approve.

### `packIndex/{packId}`

`{ name, version, ownerUid, engineMajor, tags, keywords, status, storagePath, visibility, updatedAt }`. The pack file itself is in Storage; the index is what is searched. `visibility` is `private` or `public`; public requires moderator approval like other public content. `status` is `testing` or `released` as for library items (11, Proposed).

### `listingsPending/{opId}` and `listingsPublic/{opId}`

Public operations that take join requests ([11](11-supplemental-features.md)): `{ name, gmUid, virtual, tags, keywords, createdAt }`, a subset of the operation chosen by the GM. Same pending-then-public flow. Listed to signed-in full accounts (11: "listed to signed-in users").

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
    function isAdmin()    { return request.auth.token.get('admin', false) == true; }
    function isModerator(){ return isFull() && (isAdmin() || request.auth.token.get('moderator', false) == true); }
    function pageOk()     { return request.query.limit <= 50; }
    function changes(fields) {
      return request.resource.data.diff(resource.data).affectedKeys().hasAny(fields);
    }
    function doc(path)    { return get(/databases/$(database)/documents/$(path)); }
    function opGm(op)     { return doc('operations/' + op).data.gmUid; }
    function myBadge()    { return doc('agents/' + uid()).data.badgeNumber; }
    function levelOk(level, claim) { return level in request.auth.token.get(claim, []); }
    function visibleStatus(status) { return status == 'released' || tier() >= 5; }

    match /agents/{id} {
      allow get: if isFull() && id == uid();
      allow update: if isFull() && id == uid()
        && !changes(['badgeNumber', 'createdAt', 'ageBracket']);
      // create and delete: function only (Admin SDK bypasses rules)
    }

    match /profilesPublic/{badge} {
      allow get: if true;                       // the public page; sign-in requirement is a question for R
      allow list: if isFull() && pageOk();
      allow create, update, delete: if isModerator();
    }
    match /profilesPending/{badge} {
      allow get: if isFull() && (badge == myBadge() || isModerator());
      allow list: if isModerator() && pageOk();
      allow create, update: if isFull() && badge == myBadge()
        && request.resource.data.badgeNumber == badge;
      allow delete: if isModerator() || (isFull() && badge == myBadge());
    }

    match /badgeNumbers/{n}  { allow read, write: if false; }
    match /signInCodes/{c}   { allow read, write: if false; }

    match /aliases/{owner}/items/{aliasId} {
      allow get: if signedIn() && owner == uid();
      allow list: if signedIn() && owner == uid() && pageOk();
      // anonymous: one fixed-key document, only if absent
      allow create: if signedIn() && owner == uid()
        && (isFull() || (aliasId == 'anon'
            && !exists(/databases/$(database)/documents/aliases/$(owner)/items/anon)));
      allow update, delete: if signedIn() && owner == uid();
    }

    match /operations/{op} {
      allow get: if signedIn() && (uid() in resource.data.memberUids || resource.data.gmUid == uid());
      allow list: if signedIn() && pageOk()
        && (uid() in resource.data.memberUids || resource.data.gmUid == uid());
      allow create: if isFull() && tier() >= 4
        && request.resource.data.gmUid == uid()
        && request.resource.data.memberUids == [uid()]
        && request.resource.data.status == 'open';
      allow update: if isFull() && resource.data.gmUid == uid()
        && request.resource.data.gmUid == resource.data.gmUid
        && resource.data.status != 'archived'
        && request.resource.data.status != 'archived';   // admin SDK only
      // delete: function only

      match /members/{m} {
        allow get: if isFull() && (uid() == m || opGm(op) == uid());
        allow list: if isFull() && pageOk() && opGm(op) == uid();
        allow write: if isFull() && opGm(op) == uid();
      }
      match /invites/{t} {
        allow get: if isFull() && opGm(op) == uid();
        allow list: if isFull() && pageOk() && opGm(op) == uid();
        allow write: if isFull() && opGm(op) == uid();
      }
      match /requests/{r} {
        // anonymous accounts can join any session (06); only public operations take requests
        allow create: if signedIn() && r == uid() && request.resource.data.status == 'open'
          && doc('operations/' + op).data.visibility == 'public';
        allow get: if isFull() && opGm(op) == uid();
        allow list: if isFull() && pageOk() && opGm(op) == uid();
        allow update, delete: if isFull() && opGm(op) == uid();
      }
      match /transfers/{t} {
        allow create: if isFull() && request.resource.data.fromUid == uid()
          && request.resource.data.status == 'offered'
          && exists(/databases/$(database)/documents/aliases/$(uid())/items/$(request.resource.data.aliasId));
        allow get: if isFull() && (resource.data.fromUid == uid() || opGm(op) == uid());
        allow list: if isFull() && pageOk() && opGm(op) == uid();
        allow update: if isFull() && opGm(op) == uid()
          && resource.data.status == 'offered'
          && request.resource.data.status in ['accepted', 'declined']
          && !changes(['fromUid', 'aliasId', 'sourceOpId']);
      }
      match /missions/{mi} {
        allow get: if signedIn()
          && uid() in doc('operations/' + op).data.memberUids;
        allow list: if signedIn() && pageOk()
          && uid() in doc('operations/' + op).data.memberUids;
      }
    }

    match /archiveIndex/{op} {
      allow get: if signedIn() && uid() in resource.data.memberUids;
      allow list: if signedIn() && pageOk() && uid() in resource.data.memberUids;
    }
    match /archives/{op}/chunks/{n} {
      // audience is stored in the chunk, so the rule needs no lookup to read it
      allow get: if signedIn() && (
        doc('archiveIndex/' + op).data.gmUid == uid()                         // GM reads every audience
        || (resource.data.audience == 'public'
            && uid() in doc('archiveIndex/' + op).data.memberUids)
        || (resource.data.audience.matches('alias:.*')
            && resource.data.audience == 'alias:'
               + doc('operations/' + op + '/members/' + uid()).data.aliasId));
      allow list: if false;  // clients fetch by id from archiveIndex.chunkCount
    }

    match /libraryPending/{id} {
      allow get: if isFull() && (resource.data.ownerUid == uid() || isModerator());
      allow list: if isFull() && pageOk() && (isModerator() || resource.data.ownerUid == uid());
      allow create: if isFull() && (isModerator() || request.resource.data.ownerUid == uid());
      allow update: if isFull() && resource.data.ownerUid == uid()
        && request.resource.data.ownerUid == uid();
      allow delete: if isFull() && (resource.data.ownerUid == uid() || isModerator());
    }
    match /libraryPublic/{id} {
      allow get: if signedIn() && levelOk(resource.data.summaryLevel, 'summaryLevels')
        && visibleStatus(resource.data.status);
      allow list: if signedIn() && pageOk() && levelOk(resource.data.summaryLevel, 'summaryLevels')
        && visibleStatus(resource.data.status);
      allow create, update, delete: if isModerator();
    }
    match /libraryData/{id} {
      allow get: if signedIn() && levelOk(resource.data.dataLevel, 'dataLevels')
        && visibleStatus(resource.data.status);
      allow list: if false;
      allow create, update, delete: if isModerator();
    }

    match /packIndex/{id} {
      allow get: if signedIn() && (resource.data.visibility == 'public' || resource.data.ownerUid == uid())
        && visibleStatus(resource.data.status);
      allow list: if signedIn() && pageOk()
        && (resource.data.visibility == 'public' || resource.data.ownerUid == uid())
        && visibleStatus(resource.data.status);
      allow create: if isFull() && request.resource.data.ownerUid == uid()
        && (request.resource.data.visibility == 'private' || isModerator());
      allow update: if isFull() && (isModerator()
        || (resource.data.ownerUid == uid() && request.resource.data.ownerUid == uid()
            && request.resource.data.visibility == 'private'));
      allow delete: if isFull() && (resource.data.ownerUid == uid() || isModerator());
    }

    match /listingsPublic/{op} {
      allow get: if isFull();
      allow list: if isFull() && pageOk();
      allow create, update, delete: if isModerator();
    }
    match /listingsPending/{op} {
      allow get: if isFull() && (resource.data.gmUid == uid() || isModerator());
      allow list: if isFull() && pageOk() && (isModerator() || resource.data.gmUid == uid());
      allow create, update: if isFull() && request.resource.data.gmUid == uid();
      allow delete: if isFull() && (resource.data.gmUid == uid() || isModerator());
    }
  }
}
```

Notes on the draft:

- `profilesPublic` `get: if true` lets an unauthenticated browser read the public page by badge number; enumeration (`list`) needs sign-in. Whether the page should require sign-in is a question for R.
- A `list` rule that tests `resource.data` only passes when the query itself constrains the same field (for example `where memberUids array-contains uid`). Firestore refuses a list the rule cannot prove from the query. Each query in the next section is written to satisfy its rule `[U]`.
- A `get` that errors inside `||` (for example a missing member document in the archive chunk rule) is treated as false for that branch `[U]`; test it.
- Lookups per request: archive chunk 3, operation subcollections 1 to 2, `profilesPending` 1; all inside the 10 cap [V-7].

## Queries and composite indexes

Every query the app runs, so a `FAILED_PRECONDITION` [V-43] is a deploy error and not a surprise. Single-field indexes are automatic and not listed. An inequality or `in` filter on a field must be the first ordering, so the browse queries order by the level field first.

| Query | Index |
|---|---|
| Library browse: `kind ==`, `summaryLevel in [...]`, order `summaryLevel, name` | `libraryPublic`: `kind ASC, summaryLevel ASC, name ASC` |
| Library keyword search: `keywords array-contains`, `summaryLevel in [...]`, order `summaryLevel, name` | `libraryPublic`: `keywords ARRAY_CONTAINS, summaryLevel ASC, name ASC` |
| Library tag filter, same shape | `libraryPublic`: `tags ARRAY_CONTAINS, summaryLevel ASC, name ASC` |
| My pending submissions | `libraryPending`: `ownerUid ASC, createdAt DESC` |
| Moderation queues | single field `createdAt` on `libraryPending`, `profilesPending`, `listingsPending` |
| Operations I GM | `operations`: `gmUid ASC, createdAt DESC` |
| Operations I am in | `operations`: `memberUids ARRAY_CONTAINS, createdAt DESC` |
| Public operations by tag or keyword | `listingsPublic`: `tags ARRAY_CONTAINS, createdAt DESC` and `keywords ARRAY_CONTAINS, createdAt DESC` |
| Transfer requests for my operation | none (subcollection, filter `status ==` on one field) |
| Packs by keyword or tag | `packIndex`: `visibility ASC, keywords ARRAY_CONTAINS, name ASC` and `visibility ASC, tags ARRAY_CONTAINS, name ASC` |
| My packs | `packIndex`: `ownerUid ASC, name ASC` |
| Missions of an operation | none (subcollection, ordered by `startedAt`) |

Deployed as `firebase/firestore.indexes.json` and `firebase/firestore.rules` when built. `[U]` None of these indexes has been created or queried; only the missing-index error behaviour is verified [V-43]. Searching archived missions by keyword (FS4) needs keyword fields on `missions` or `archiveIndex` and is **Held** with X0.

## Test plan (Emulator Suite)

Not run. When built, mirror `firebase/rtdb_rules_test/`:

1. Anonymous account: creates `aliases/<uid>/items/anon` once; second create refused; any other id refused; cannot read `agents`, cannot create `operations`, cannot read `libraryData`; can create a join request on a public operation.
2. Tier gates: tier 3 cannot create an operation; tier 4 can; a lapsed handler (claim back to 3) cannot create but can read.
3. Owner isolation: `agents` and `aliases` readable only by the owner; `ageBracket` and `badgeNumber` not owner-editable; `badgeNumbers` and `signInCodes` refused for everyone.
4. Operation membership: non-member `get` and `list` refused; `gmUid` change refused; a client cannot set `status: 'archived'`; a player cannot add themselves to `memberUids`; a member reads only their own `members` entry; a requester cannot read their request.
5. Archive audiences: GM reads all three audience kinds; a member reads `public` and only their own `alias:<id>`; `list` refused; missing member document gives a refusal, not an error.
6. Library levels: a caller with `summaryLevels: [1,2]` reads level 1-2 summaries and not level 3; `libraryData` follows `dataLevels`; `testing` items only for tier 5; owner cannot write `libraryPublic`; moderator can; revocation back to pending works.
7. Pending then public for profiles, listings and packs; a non-moderator cannot make a pack `public`; pack delete works for owner and moderator.
8. Transfers: only the alias owner creates, only the destination GM decides, a decided request cannot be flipped.
9. Pagination: list queries without `limit`, or with `limit > 50`, refused [V-49].
10. Queries: each query in the index table run against emulator indexes, and one without its index returns `FAILED_PRECONDITION`.
11. Claim refresh: tier change visible only after a forced token refresh [V-42][V-43].

## Held and questions for R

**Held on X0 or D:** the archive layout per mission, the genesis `archives` fields and `missions.eventRange` unit (X0, Q24); carrying alias state between missions (Q24); the public profile's alias, operation and mission lists (X0); mission submissions as a library kind with summary and clearance level, the archive pending/public pair and news (06, 11); the feedback collection (write-only for users, admins read; 11, Proposed); the consent opt-in storage (11); the tier-to-levels map behind `dataLevels` and `summaryLevels` (R to rule).

**Proposed choices that need R's call:**

1. **Moderation by client write or by function.** The draft lets a moderator account write the public collections directly. The alternative is a function, which avoids a client claim with write access but needs an HTTPS call per approval.
2. **Merge `verifier` into `moderator`.** 11 mentions a verifier; the draft has only `admin` and `moderator` claims, and the `verifier` field on library items.
3. **A function to issue a badge number and create the `agents` document** when an account becomes a full account (clients cannot).
4. **Level claims.** `dataLevels` and `summaryLevels` as custom claims (small lists) versus a lookup document per tier.
5. **Unauthenticated `get` on `profilesPublic/{badge}`** (needed for the public page; confirm it is intended).
6. **Array size caps** on `memberUids`, `tags`, `keywords` (rules can bound `.size()`; the numbers are unchosen).
7. **TTL policy** on `signInCodes.expiresAt`.
8. **Transfer move by function** (the draft assumes one; rules cannot check that the source operation is not running).
