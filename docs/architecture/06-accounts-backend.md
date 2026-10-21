# 06. Accounts and backend

## Backend role (Fixed)

Accounts, session persistence and relay, rules pack distribution, information dissemination (news, D's announcements), payments. The backend **never runs game rules**: no backend code imports the engine (see dependency rules in [00-overview.md](00-overview.md#dependency-rules)).

## Stack (Fixed: adopted by R)

R adopted the stack from the backend-split investigation (project library: `architecture/backend-split.md` and its review). Firebase-first stays the preference, with the Firebase console as the admin tool for D and content auditors. R then split data between two databases (FS1, below): RTDB for live play, Firestore for data at rest.

| Layer | Choice | Notes |
|---|---|---|
| Client SDK | `firebase_dart` 1.6.2 (Auth, Realtime Database, Storage) as the adapter wherever it runs. Auth and RTDB probed [V-21]; Storage **not yet probed** | FlutterFire where `firebase_dart` cannot run (web), including `cloud_firestore` for Firestore on web |
| Live game data | **Firebase Realtime Database (RTDB)**: relay, active operation events, requests, members, phone, signaling, presence, head while active, inbox | Live play only (FS1) |
| Data at rest | **Cloud Firestore**, Standard edition: archived operations, library, pack index, searchable account data | Fixed (FS1, FS4). Desktop access through a hand-written REST client (FS2) |
| Files | Cloud Storage for Firebase (rules pack files) | Uploads by D through the console. Client Storage access through `firebase_dart` is unproven (open item B2) |
| Server code | **HTTPS-only Dart Cloud Functions** (experimental; R accepted that) [V-23] | Function list under [Cloud Functions](#cloud-functions-dart-https-only-fixed-p14) |
| Hosting | Firebase Hosting (web build) | — |
| Cloud Run | No separate service planned | The earlier desktop Cloud Run gateway is dropped; Dart functions themselves deploy to Cloud Run [V-33] |

Platform targets in v1 (R, 2026-10-20): **Windows and Linux desktop**, plus the web player build (W1). macOS and iOS are not in v1. `firebase_dart` was probed on Windows and on Linux with identical results [V-21], and every later client probe ran on both [V-39]–[V-41][V-44] except 8.4 [V-42] and the FS2 claims/index follow-up [V-43] (Linux only). Android was not probed.

### Backend port and adapters (Fixed: P10a)

Ruled by R 2026-10-20 (P10a). `session` talks to the backend only through a **backend port** with these capabilities: auth, tree store (RTDB-shaped reads/writes with rules), event stream (live listeners), blob fetch (Storage), and a **document store** (Firestore: get, set, query, paged reads). Implementations live in the `backend` package:

| Adapter | Used on | Built on |
|---|---|---|
| `FirebaseDartAdapter` | Windows and Linux (probed) | `firebase_dart` for Auth, RTDB, Storage; the hand-written Firestore REST client (below) for the document store |
| `FlutterFireAdapter` | where `firebase_dart` cannot run (web) | FlutterFire plugins, including `cloud_firestore` |
| `LanAdapter` | LAN/in-person play with no backend | session transports |

Swapping adapters never touches session or engine. FlutterFire `cloud_firestore` 7.0.0 failed to link on Windows in the probe [V-22], which is why desktop does not use it.

### Firestore (Fixed: FS1, FS2, FS4, FS5)

Ruled by R 2026-10-20. Firestore runs alongside RTDB (this answers B1 and reverses the earlier "Firestore out of the v1 client"). R's reasons: no database migrations for large structural changes or format additions; infrequent operations move to an API that supports them; Firestore querying is more efficient for GMs and users searching past operational data, items, archives and packs.

**FS1 split.**

| Store | Holds |
|---|---|
| RTDB (live play only) | Active operation events, requests, members, phone, signaling, presence, head snapshot while active, inbox |
| Firestore (data at rest) | Archived operations (frozen event log, text log, final head snapshot), library (pending and public), pack index (pack files stay in Storage), searchable account data (profiles, aliases, campaigns, news) |

**FS2 desktop client.** No Firestore SDK runs on desktop for us. `backend` contains a small hand-written Firestore REST client behind the backend port; it calls `getIdToken()` on `firebase_dart` for every request and sends the token as a Bearer header, and Security Rules authorize the request [V-36]. Web uses FlutterFire `cloud_firestore`. Probed on Windows and Linux [V-32]: PATCH write 200, `runQuery` with filter, `orderBy` and `limit` 200, rules enforced (403 on a denied path and with no token), `getIdToken(true)` refresh works, a bad token gives 401.

Follow-up probe [V-43]: a query that needs a composite index returns 400 `FAILED_PRECONDITION` ("The query requires an index") until the index is READY, then 200; a rule on a custom claim (`request.auth.token.role == 'gm'`) gives 403 without the claim and 200 once the claim is set and the token force-refreshed. So the REST client (Proposed, follows from FS2):
- surfaces `FAILED_PRECONDITION` as a missing-index error (a deploy problem, not a user error); every query the app runs has its composite index declared with the Firestore collection draft (P10c);
- forces `getIdToken(true)` after a role change before relying on a claim (see [Roles](#roles)).

**Natural expiry** (Linux, `firebase_dart` 1.6.2, session restored from storage in a second process [V-45]): a stale ID token gets 401 from Firestore REST, and a plain `getIdToken()` after expiry returns a new working token by itself. Proposed: the REST client calls `getIdToken()` for **every request** and never caches the token string; on a 401 it retries once with `getIdToken(true)` before surfacing a sign-in error. Not tested: revoked sessions, disabled users, password change, refresh-token failure, Windows [V-45].

**FS4 search.** Standard edition: structured queries (equality, range, array-contains on keyword and tag fields), with composite indexes where needed. No full-text search. Text search needs an Enterprise edition database; revisit Enterprise only if text search is needed later [V-36]. Standard bills per document read [V-36].

**FS5 document sizing.** Archived event and text logs are chunked into a subcollection (one document per N batches), never one document per operation, to stay under the 1 MiB document cap [V-7]. A function wrote and read back a chunk of about 920 KiB (900 items) through `firebase_admin_sdk` [V-33].

**Held (P10c): the Firestore collections themselves are still to be drafted** (collection names, document shapes, rules, indexes), now that FS2 has reported. Rules are tested in the Emulator Suite (P10b).

## Account model (Fixed concepts, Proposed fields)

```
Agent (account)
  ├─ id (= Firebase Auth uid)
  ├─ kind: full | anonymous
  ├─ displayName
  ├─ badges[]            optional scannable login credentials (revocable)
  └─ aliases[]
        Alias
          ├─ id, name, portrait
          ├─ campaignId?          locked to at most one campaign at a time
          └─ transferRequest?     pending move, needs that campaign's GM approval
Campaign
  ├─ id, name, gmAgentId
  ├─ members: aliasIds
  ├─ packRefs
  └─ operations[]
```

Profiles, aliases and campaigns are searchable account data and live in Firestore (FS1). Field-level shapes remain Proposed until the Firestore collections are drafted (Held, P10c).

Rules:

- An alias is locked to one campaign (Fixed). **Transfers (Fixed: concern 4, ruled by R 2026-10-20):**
  - The **destination** campaign's GM approves a transfer.
  - The **source** campaign is notified; it does not consent.
  - An alias in a **running operation cannot move** until that operation ends.
  - The transfer request is a Firestore document under the destination campaign, approvable only by its GM (Firestore rules).
- **Anonymous accounts** (Fixed): can join any session, have exactly one alias, cannot GM, host or create content. Anonymous sign-in works in `firebase_dart` on Windows and Linux [V-21].
- **Upgrading an anonymous account** (probe 8.5, Windows and Linux [V-39]). `linkWithCredential` is an `UnimplementedError` stub in `firebase_dart` 1.6.2 [V-39], and signing in with email after anonymous gives a **new** uid [V-21], so neither is used. Proposed upgrade path:
  - Call `updateEmail` then `updatePassword` on the signed-in `firebase_dart` user. This keeps the uid, clears `isAnonymous`, and later email sign-ins return the same uid [V-39].
  - Do **not** call the Identity Toolkit `accounts:update` REST endpoint out of band for this. It also keeps the uid, but it leaves `firebase_dart`'s stored session inconsistent (Linux: `reload()` fails with `user-token-expired`; Windows: `reload()` still reports anonymous) [V-39].
  - Map `EMAIL_EXISTS` and `WEAK_PASSWORD` to user-facing messages [V-39].
  - After upgrading, force `getIdToken(true)` before any host, GM or content command: the token issued before the upgrade still says `sign_in_provider: anonymous` (decoded, not re-verified) [V-39], and the rules refuse anonymous tokens for those writes (shown in the emulator with hand-built tokens [V-38]).
  - The upgraded account has `email_verified: false` [V-39]; whether hosting needs a verified email is a design choice for R, not decided here.
- Anonymous data does not survive clearing local storage or switching devices [V-8]; the UI says so before an anonymous player invests in a character.
- Enforcement: the session refuses host/GM/content commands from anonymous agents, and rules in RTDB and Firestore refuse the corresponding writes using `auth.token.firebase.sign_in_provider` [V-9]. The RTDB rules prototype refuses `meta`, head and event writes from anonymous tokens in the emulator [V-38]; live tokens carry the values the rules check (`anonymous`, `password`, `custom`) [V-39][V-41]. Rules on the deployed database are not tested yet.
- **One alias per anonymous account** is enforced in three places:
  1. **Backend.** The anonymous one-alias rule **moves to Firestore** (P10c): Proposed mechanism: an anonymous account's alias is a single fixed-key document, creatable only when it does not already exist, so a second alias is impossible. Full accounts use generated ids. Held: the exact document path and rule wait on the Firestore collection draft (rule behaviour unproven until the Emulator Suite tests).
  2. **App.** The account repository hides "create alias" for anonymous agents once that alias exists and offers the upgrade instead.
  3. **Session (local and LAN play without the backend).** A guest agent identity carries `kind: anonymous`; `OperationHost` refuses a `hello` that presents a second alias for the same anonymous agent id.

## Roles

Admin, moderator and payment tier are **custom claims** on the Auth token, set by the roles Cloud Function with `firebase_admin_sdk` (which supports `setCustomUserClaims`) [V-24]. Rules read them from `auth.token` [V-9]: shown for Firestore rules [V-43], not yet tested in RTDB rules. In probe 8.4 a forced `getIdToken(true)` showed a new claim about 37 s after polling started (including R's manual step), and so did `reload()`; the plain `getIdToken()` never did within the 4-minute window [V-42] (Linux only; Windows not run). 

Design (Proposed): when the roles function changes a claim, it also writes an inbox notice to `/inbox/$uid` (P14); the client that receives it calls `getIdToken(true)` and reloads its `Entitlements` read model. Whether a client that never gets the notice picks up the claim when its token next refreshes on expiry is **untested**: V-45 shows the token refresh, not claims, and in V-42 the plain `getIdToken()` did not show the claim while the old token was still valid.

## Badges (Fixed: P9, conditional on probe 8.3)

Ruled by R 2026-10-20 (P9). A badge is a printable/scannable code on a physical agent badge that signs an agent in. The ruling was conditional on probe 8.3, which **passed** on Windows and Linux [V-41].

- **Sign-in path:** scanning sends the badge credential to the **badge-login HTTPS Dart function**, which verifies it and returns a custom token minted with `firebase_admin_sdk` `createCustomToken` [V-24]; the app signs in with `signInWithCustomToken`. Firebase rules see `sign_in_provider == "custom"` [V-9][V-41]. Developer claims put in the token at minting survive a forced refresh [V-41].
- **Symbology:** PDF417, not QR.
- **Payload:** only the badge id and a 256-bit secret (about 70 ASCII characters). The secret is stored **hashed**; the badge is revocable and never carries a password.
- **Evidence:** a malformed custom token is rejected with `invalid-custom-token` [V-21]. A token minted in a deployed function (`createCustomToken`, no key file) signed in via `firebase_dart` on Linux once the runtime service account held Service Account Token Creator [V-33]. A real custom token (minted with `gcloud iam service-accounts sign-jwt`) signed in on **Windows and Linux** [V-41]. The badge function and the flow end to end are not built yet.
- **Deploy checklist:** grant **Service Account Token Creator** (`roles/iam.serviceAccountTokenCreator`) to the function's runtime service account on itself; without it `createCustomToken` fails with `iam.serviceAccounts.signBlob` denied [V-33].
- **Packages not approved yet:** printing (candidate `barcode`), phone scanning (`mobile_scanner`), desktop scanning (`flutter_zxing`, Windows/Linux beta, or USB 2D keyboard-wedge scanners). Each goes to R when badges are scheduled.
- Badges are optional, per agent, listed and revocable from account settings.
- Offline: a badge cannot create a new sign-in without the backend. An agent already signed in on that device keeps working from the local cache.

## Offline accounts (Fixed requirement)

A signed-in account works offline from a local cache. The app keeps its own local record (profile, aliases, campaigns, packs by content hash, operation logs) in the local store (sembast, 09-3; see [04-session.md](04-session.md)).

`firebase_dart` does **not** keep pending writes across a restart. Probe 8.1 on Windows and Linux [V-40]: a write queued while offline is readable locally, but after the app exits or is killed and restarts, it is gone from the server and from the local cache. A write that reached the server before the restart is still in the local cache afterwards. Within one process, a write queued with `goOffline` is delivered on `goOnline` [V-21].

So the session's **outbox is required**, not a precaution: requests made offline are stored in the local store (sembast) and replayed as ordinary requests on reconnect; the GM stays canonical, so replay is safe (dedupe by request id, [03-protocol.md](03-protocol.md#ordering-and-delivery)). The app never relies on the SDK's offline queue to carry a write past the end of the process.

### Auth token storage (Fixed: B5)

Ruled by R 2026-10-20 (B5). By default `firebase_dart` 1.6.2 stores the refresh token and email in plaintext in the Hive box `firebase_auth`, and `FirebaseDart.setup` has no storage option [V-34]. The design:

- After `FirebaseDart.setup` and **before any `FirebaseAuth` use**, `backend` opens the Hive box `firebase_auth` with `HiveAesCipher(key)`. That encrypts the box [V-34].
- The key lives in the OS secure store via `flutter_secure_storage` 11.2.0. Linux: libsecret (Secret Service) [V-34]. **Windows: not Credential Manager**, but a JSON file of DPAPI-protected values at `%APPDATA%\<company>\<product>\flutter_secure_storage.dat` (`flutter_secure_storage_windows` 4.2.2), tied to the Windows user account [V-44]. The folder follows the app's Windows company and product names, so the Windows runner sets them deliberately before the first release; renaming them later orphans the key (key loss, below).
- **Guard 1, key access and migration.** Reading or creating the key never fails silently: a wrong or missing key makes Hive truncate the box and sign the user out, on Linux and Windows alike [V-34][V-44], so a key failure is surfaced, not swallowed. **Key loss means no session** [V-44]. Requirement: the app shows that the user must sign in again and does not treat it as an error loop. A plaintext-to-encrypted migration step handles boxes written before encryption: it reads the plaintext box before any encrypted open, then rewrites it encrypted. Opening an existing plaintext box with the cipher was not probed, so the migration is tested before release.
- **Guard 2, locked keyring.** On Linux a locked keyring with no prompter blocks the libsecret call forever and freezes the event loop [V-34], so key access runs under a timeout guard and reports instead of hanging. A missing Secret Service gives a clean error [V-34]. Windows showed no hang [V-44]; the guard stays on every platform.
- **Dependency:** `hive` 2.2.3 is a direct dependency of `backend`, **pinned exactly**. It must be the same `hive` package `firebase_dart` uses (`hive` ^2.0.0, not `hive_ce`) [V-35].
- **Known accepted risk:** `firebase_dart` depends on `hive`, which has had no release since 2.2.3 (2022-06-30) [V-35], and on `firebaseapis` 0.2.0, whose repository was archived on 2026-03-24 (per the backend investigation, project library `architecture/firebase-desktop-deep-dive.md`).
- Not tested: KWallet (no Secret Service bridge).

## Realtime Database model (live play)

**P10c (Fixed).** The three open items were ruled by R 2026-10-20, and the rest of the draft was approved by R 2026-10-21 ("The rest of the proposals in the draft are approved"). Drafted from probe 8.6, whose rules pass 116 of 116 checks in the Emulator Suite [V-38]. R ruled on the three items the probe left open (see [R's rulings](#p10c-rulings-r-2026-10-20) below); the rest of the draft is the probe-backed design R approved (review sheet: project library `architecture/rtdb-draft-review.md`, P1-P24). The rules file is in the repository at `firebase/database.rules.json`, started from probe 8.6's prototype with the three rulings applied and the prototype's `phoneDraft` path removed (R 2026-10-21, P23). Its emulator checks are in `firebase/rtdb_rules_test/` (P10b, [08-testing.md](08-testing.md#backend); how to run them: `firebase/README.md`). They pass 200 of 200 in the Emulator Suite, including the three rulings, the post-archive clean-up [V-50], R's rulings of 2026-10-21 on presence, `meta` validation and anonymous members [V-51] and the review follow-ups R approved the same day [V-52] (see [Rules rulings, 2026-10-21](#rules-rulings-r-2026-10-21)). Under FS1, RTDB keeps **live play only**; everything at rest is in Firestore (collections still to be drafted).

```
/operations/$op/meta                     gm uid, campaignId, engine version, packRef, status (required string), locked (boolean; once set, never removed), lastSeq
/operations/$op/members/$uid             { aliasId, joinedAt }; written by the GM client only
/operations/$op/requests/$uid/$push      { id, kind, from == $uid, ... }; the member writes own uid only, create-only
/operations/$op/events/$audience/$push   { seq, body }; GM only; create-only; .indexOn seq
/operations/$op/textlog/$audience/$push  { seq, text }; GM only; create-only; .indexOn seq
/operations/$op/head                     head snapshot; GM only (read and write)
/operations/$op/phone/$uid/$push         phone box per player: player and GM messages; the player writes own box (from == $uid), the GM writes any box; { from, text } with text at most 2,000 UTF-16 units (field names are the implementation's choice); cleared when the "mission" ends (P17)
/operations/$op/signaling/$uid/...      WebRTC offer/answer/candidates (P2P mode only); written by that uid or the GM; frozen by locked (rulings 2, 3 [V-50])
/presence/$op/$uid                       own presence; members write own uid until the operation is archived; members and GM read
/inbox/$uid/$push                        in-app notifications (P14); owner reads and deletes; only functions write
```

`$audience` is `gm`, `public` or `alias:<aliasId>`, checked by a `.validate` pattern [V-38].

Who can do what (shown in the emulator [V-38]; the `meta` and `signaling` changes from R's rulings are shown by the repository's rules checks [V-50]):

| Path | GM | Member (player) | Others |
|---|---|---|---|
| `meta` | creates it (non-anonymous, naming itself `gm`), edits until locked; `gm` cannot change; never deletes, and every write keeps `gm` as the writer (ruling 1 [V-50]); `status` cannot be removed and `locked` must be a boolean [V-51] and once set is never removed [V-52] | reads | — |
| `members` | reads all, writes entries until locked | reads own entry only, cannot list | — |
| `requests` | reads and clears | creates under own uid with `from == auth.uid`; cannot read requests at all, own included | — |
| `events`, `textlog` | reads every audience; appends, never overwrites or deletes | reads `public` and `alias:<own aliasId>` only | — |
| `head` | reads and writes until locked | — | — |
| `phone` | reads every box, delivers into any box | reads own box, appends to it (create-only: no client edits or deletes a message); anonymous members read only their own box [V-51]; messages need string `from` and `text` of at most 2,000 UTF-16 units (field names are the implementation's choice) [V-52] | — |
| `signaling` | reads (as probed); writes any uid's branch until locked | reads (as probed); writes own uid's branch until locked; anonymous members cannot read or write [V-51][V-52] | — |
| `presence/$op` | reads (writes own uid only if also a member) | reads; writes own uid until `meta/status` is `archived` [V-51] | — |
| `inbox/$uid` | — | owner reads and deletes | functions write (admin REST) |

After `meta/locked = true` the GM cannot append, write head, add members or unlock, and members cannot write requests or phone [V-38]; signaling is frozen too (ruling 3 [V-50]); presence stays writable while the lock holds (the post-archive clean-up below then deletes it and closes it), and the inbox is written only by functions, so the lock does not affect it; reads continue. Anonymous accounts can be members and write requests, and cannot create operations, write GM-only paths, send phone messages or write signaling (no voice or video) [V-51].

What probe 8.6 changed in the earlier draft:

- **Phone is per player box** (`phone/$uid/$push`), not one `phone/$push` list "read by GM and sender". A client cannot list a parent it has no read on, so a sender could never list their own thread in the old shape [V-38]. Phone messages remain engine events (`PhoneMessageSent`, see [04-session.md](04-session.md#in-game-phone)). **Box contents and lifetime.** Fixed (R 2026-10-21, P17): "GM messages go into the box as well. The box should only be cleared once a mission ends." Which spec unit a "mission" maps to waits on Q24 and Q7 ([11-supplemental-features.md](11-supplemental-features.md)). **Mechanism (Fixed, R 2026-10-21: "For P17, let's go with your proposal"):** the `PhoneMessageSent` events in the audience branches stay the record, and a function clears the box with admin REST after the archive is written, because the probed phone write rule is create-only (`!data.exists()`), so no client can delete a message [V-38]. **Analysis (an approximation, not a measurement):** about 12 KB per 4-hour session at the assumed profile, so no storage concern (project library `architecture/rtdb-traffic-cost-estimate.md`, flag 1).
- **The GM's read sits on each parent** (`members`, `requests`, `events`, `textlog`, `phone`). Read rules cascade downward, so child rules only handle players [V-38].
- **Resync indexes:** `events/$audience` and `textlog/$audience` declare `.indexOn: ["seq"]`; `orderBy="seq"&startAt=N` and `limitToLast` then work for members. Catch-up by key needs no index (as in [V-33]). An unindexed `orderBy` is refused with 400 on REST [V-38].
- **Refusals are indistinguishable.** A failed `.validate` returns the same 401 `Permission denied` as an unauthorized write, so the client logs the refused payload locally to tell the two apart in debugging [V-38].
- **Rules do not check `seq` order or gaps.** That stays the GM client's job; rules only require a numeric `seq`, create-only keys and a valid audience [V-38].
- **The one-alias rule is not in RTDB.** It is in Firestore (Held with the Firestore collections); RTDB only checks that a member entry carries one `aliasId` [V-38].
- **Lookups per evaluation** are at most 3 `root.child` reads, under the limit of 10 the probe write-up cites for RTDB rules [U] (a static count, not a load test) [V-38].

### P10c rulings (R, 2026-10-20)

The probe found two weaknesses and one open question [V-38]. R's answer, verbatim: "I'll take your recommendations on P10c 1 and 2. Yes meta/locked should freeze." (the third item asked whether the lock also freezes signaling). All three are applied in `firebase/database.rules.json` and shown by its emulator checks [V-50] ([08-testing.md](08-testing.md#backend)); deployed rules with real signed tokens are still untested.

1. **No delete on `meta`.** In the prototype, the GM could delete `meta` of an unlocked operation, and any full account could then recreate it naming itself GM. Ruling: `meta` cannot be deleted; status and lock are edited, never removed. In the rules, every `meta` write must leave `gm` equal to the writer, so deleting `meta` or `meta/gm` is refused; the lock then refuses all `meta` writes.
2. **Signaling keyed by uid.** In the prototype, any member could overwrite any `signaling/$peer`, including another player's offer. Ruling: signaling lives under `signaling/$uid/...`, written only by that uid or the GM. Read scope is the probed rules' (members and the GM), narrowed so anonymous members cannot read it (see ruling 3 below). Only matters for P2P mode, which is built last (09-4).
3. **Lock freezes signaling.** `meta/locked = true` also freezes signaling writes. Presence stays writable under the lock (as recommended) until the post-archive clean-up deletes it; the inbox is written only by functions, so the lock does not touch it.

### Rules rulings (R, 2026-10-21)

R's answer to the three gaps the rules checks left open, verbatim: "I'll take your recommendations for 1 & 2. Anonymous players should not be able to join voice and video or send messages as age verification happens on account creation." Recorded in `firebase/database.rules.json` and shown by its emulator checks [V-51].

1. **Presence closes once archived.** The archive step sets `meta/status` to `archived` and the post-archive clean-up deletes `presence/$op`; presence writes are refused while `meta/status` is `archived`. The marker value `archived` is the rules file's choice (status values are otherwise not fixed yet).
2. **`meta` validation.** `meta` must carry `gm` and `status`; `status` is a string and cannot be removed; `locked` must be a boolean.
3. **Anonymous members do not message or signal.** An anonymous (clearance 0) member cannot read or write signaling, so cannot join voice or video, and cannot send phone messages; they can still read their own box, write requests and write presence. Age verification happens at account creation, so only full accounts message.

Review follow-ups, approved by R the same day ("Yes to all of these.") and shown in the emulator [V-52]:

- **Archive order:** lock, then archive, then clean-up (see "Archiving" below).
- **No signaling reads for anonymous members** (part of 3 above).
- **Phone message shape:** each message carries string `from` and `text`; `text` is at most 2,000 UTF-16 units, for GM and player messages alike. The field names are the rules file's choice until the phone message payload is drafted.
- **`locked` is never removed:** once `meta/locked` exists it cannot be deleted, before or after the lock, so before the lock it can only be set to `true` or `false`, and after the lock it cannot change at all (ruling 1: "status and lock are edited, never removed").
- **Non-member reads of the text log** are refused (root, `gm` and `public` branches; check added).

Second round of review follow-ups, approved by R the same day ("Yes let's fix those now") and shown in the emulator [V-53]:

- **`archived` is admin-only:** the rules refuse `meta/status = archived` from any client, the GM included, before or after the lock (also when the whole `meta` is replaced). Only the archive step (admin REST) sets it. After the lock, status cannot change at all.
- **Phone length unit:** the 2,000 limit is checked with the rules language's `.length`, which counts UTF-16 code units, so an emoji can count as 2 (1,000 emoji are accepted, 1,001 refused). Shown in the emulator and confirmed on a real RTDB [V-55]. The rule is unchanged; the limit is a size bound, not a character count.
- **Text log `alias:null`:** a non-member cannot read `textlog/alias:null`, mirroring the events check.
- **Multi-path writes:** the emulator runs PATCH writes that change several paths at once (on the operation node and from the root), and PUT and DELETE of the whole operation node, before and after the lock. Archived-status, `meta` delete and unlock refusals hold, and a write refused before the lock is rolled back as a whole (head and event stay unwritten). A PUT or DELETE of the whole operation node is refused only because that node has no write rule; the body is not evaluated [V-54].

Not covered by the probe (carry to implementation): rules deployed to a real project with signed tokens, custom claims in RTDB rules, member removal, payload size limits, load, and `firebase_dart` listeners against these rules [V-38].

Account data that the earlier draft kept in RTDB (`/users`, aliases, badges, `/campaigns` and transfers, `/packs`, `/archive/pending`, `/archive/public`, `/news`) is in Firestore under FS1 and concern 4; paths are drafted with the Firestore collections (Held).

Notes on the live tree:

- **Per-audience branches.** RTDB rules grant reads per path, so the GM reads everything, members read `public`, and an alias owner reads only their own branch. GM-only events and text are never stored where a player can read them. This replaces the earlier Firestore per-audience documents (P12).
- **Head snapshot (P12).** Non-web hosts write the head snapshot to the local store with every batch. It is **mirrored to RTDB on the GM-configurable per-operation interval** ([04-session.md](04-session.md)); events and text go to RTDB every batch.
- **Joins (B3, Fixed).** Join requests are answered by the GM client, which writes `members/$uid` under RTDB rules [V-38].
- **Archiving.** The order is lock, archive, clean-up (R 2026-10-21). The GM client first sets `meta/locked`, which rules check [V-38], so nothing more can be written to the events, textlog, head, requests, phone or signaling branches once the log is frozen (presence stays writable under the lock, ruling 3); then the `archiveOperation` function (below) copies the frozen log to Firestore; then the clean-up below runs. The lock cannot be undone, so a failed archive write is retried against the locked data; until a retry succeeds the locked operation stays in RTDB with its status unchanged, so nothing is lost; the archive step sets `archived` and the clean-up runs only after the archive write is confirmed. Archived logs are chunked into a Firestore subcollection (FS5). Migrated operations get a new id; the genesis event lists the archives ([05-migrator.md](05-migrator.md#archived-logs-fixed-ruled-by-r)). **Clean-up after archive (Fixed, R 2026-10-21, estimate flag 2 option a):** once the archive write is confirmed, a function deletes the live branches (`events`, `textlog`, `requests`, `head`, `phone`, `signaling`, `presence`) with admin REST and keeps `meta` and `members` (R 2026-10-21: "Yes, keep members") as the locked stub (`meta` is never deleted, ruling 1). This is the same step that clears the phone box (P17); archive stands in for "mission ends" until Q24 and Q7 settle the unit mapping. Admin REST bypasses rules, so the clean-up needs no rule; the checks show `meta` and `members` remain, `meta` stays locked and members can still read it [V-50]. The archive step sets `meta/status` to `archived` with admin REST, after the lock and before the clean-up deletes anything, and the rules then refuse presence writes, so a member's client cannot recreate presence after the clean-up (R 2026-10-21 [V-51]). Only admin REST can set that value: the rules refuse `archived` from any client, the GM included, before or after the lock (R 2026-10-21 [V-53]). An operation that is never archived needs a manual clean-up script, because deployed Dart functions have no scheduled triggers [V-23].
- **Scale.** RTDB's docs give about 200k simultaneous connections per database and about 1,000 writes per second per database, with multiple databases available on the Blaze plan [V-25]. Index nodes are denormalised so clients never scan large branches. Traffic and cost at an assumed table size are approximated in the project library (`architecture/rtdb-traffic-cost-estimate.md`, P24): about 2,200 writes per 4-hour session (an approximation from an assumed profile, not a measurement), about 0.15 writes per second.

## Library (Fixed: concern 5, ruled by R 2026-10-20)

The library is the government-style public archive of verified items (Fixed). It lives in Firestore (FS1) with `pending` and `public` collections (names Held until the collection draft).

- Submissions land as pending items.
- **Verification claim: R and D only**, at first. It is set by the roles function; more auditors are added later through the console. Revocable.
- Verification is a client write under **Firestore rules** (B3): a reviewer holding the claim moves an item from pending to public. A function is added later only if the rules get awkward.
- The record keeps **verifier, date and version**.
- **Revocation** puts the item back to pending with a reason; copies already in GM packs are unchanged.

## Packs

The pack index (id, version, content hash, Storage path) is in Firestore (FS1); pack files stay in Cloud Storage and D uploads through the console. Clients validate packs with the engine on load ([02-rules-packs.md](02-rules-packs.md#loading-and-validation)). The pack publishing helper function assists with index plus Storage.

## Relay

In network-hosted mode the backend relays and persists (Fixed). With this stack the live relay **is RTDB**: the GM writes event batches under `/operations/$op/events`, participants listen; players write requests under their own uid, the GM listens. A listener on a second client instance received writes in the probe, with reads and writes around 50 ms [V-21]. No custom relay server. Once an operation is archived, its log is read from Firestore.

## Cloud Functions (Dart, HTTPS-only, Fixed: P14)

Ruled by R 2026-10-20 (P14). Dart Cloud Functions are experimental and may change without notice. They require enabling the `dartfunctions` experiment in the Firebase CLI, the Blaze plan, Dart 3.9+ and a recent CLI. In production only HTTP (`onRequest`) and callable (`onCall`, including `onCallWithData`) triggers can be deployed; other triggers run only in the emulator, so there are no deployed database, storage, scheduled, Pub/Sub, Auth-blocking or task-queue triggers. Dart callables cannot be called by name from client SDKs, only by their full URL, and the Firebase console does not display Dart functions (they appear in the Cloud console) [V-23].

| Function | Does |
|---|---|
| Badge login | Verify badge id and secret (hash compare), `createCustomToken` (P9, conditional on probe 8.3) |
| Roles | Set admin / moderator / tier custom claims, including the library verification claim |
| Payment webhook | **Placeholder** until concern 6 (payments deferred): receive the provider's webhook (`onRequest`), set the tier claim |
| Store receipts | **Placeholder** until concern 6: validate app-store receipts [U] |
| Pack publishing helper | Assist publishing a pack version (index + Storage) |
| Push | Mobile/web push via `firebase_admin_sdk` Messaging [V-24] |
| `archiveOperation` | Called by the GM client with the frozen event log, text log and final head; validates the shape and writes the archive to Firestore (chunked, FS5) via `firebase_admin_sdk` (FS3). The GM client sets `meta/locked` before calling it; the clean-up follows a confirmed write |

### Calling functions from desktop (Fixed: B6)

Desktop calls a callable by its full URL with `POST`, `Authorization: Bearer <Firebase ID token>` and the body envelope `{"data": ...}`; success is `200 {"response": ...}`. Probed on Windows and Linux: 200 with the handler seeing the caller's `request.auth.uid`; a bad token gets 401 from the framework; with no token the framework did not reject (the handler saw no auth, so each handler must check `request.auth` itself) [V-33].

### Function credentials and RTDB access (Fixed: FS3)

Ruled by R 2026-10-20 (FS3), with the probe evidence in [V-33]. `firebase_admin_sdk` 0.5.6 and `firebase_functions` 0.8.0 are approved. `firebase_admin_sdk` has Auth, Messaging, Storage, App Check, Firestore, Functions and Security Rules libraries but **no** Realtime Database library [V-24]. So:

- **Firestore** writes (such as the archive) go through `firebase_admin_sdk`; a chunk of about 920 KiB was written and read back [V-33].
- **RTDB** reads and writes from a function are the function's **own REST calls** using the runtime's **default credential**: no key files and no scope handling. The probe wrote and read RTDB this way [V-33].
- **Scoping:** requests are admin (bypass rules) unless the call passes `auth_variable_override`, which switches the request to rules evaluation; the parameter is honored on REST [V-33]. Functions use it to stay scoped to rules where that is wanted. Whether an overridden uid is then allowed by a matching rule was not tested.
- **Service accounts:** each function group runs as a **dedicated runtime service account** (least privilege), not the default compute account. **Least IAM role for RTDB** [V-46]: `roles/firebasedatabase.admin` is the narrowest predefined role tested that gives RTDB REST read and write; `roles/firebase.viewer` gives read only (`roles/firebasedatabase.viewer` was not in the deciding run); `roles/firebase.admin` and `roles/editor` work but are broader. A custom role with only `firebasedatabase.instances.get` + `.update` is not enough, and the single permission that grants data access was not isolated. **Deploy checklist (Fixed, R 2026-10-20):** each function service account that reaches RTDB gets `roles/firebasedatabase.admin`; no narrower custom role is built. After creating a service account and granting Token Creator, allow 60-90 s before minting tokens [V-46]. Tested by impersonating a fresh service account, not from a deployed function running as it.
- **Custom tokens** need Service Account Token Creator on the runtime service account (see Badges).
- **No Node function** (B3). Anything needing database, auth or scheduled triggers is designed out or done as a manual script.

**B3, who writes what.** Joins: written by the GM client under RTDB rules. Library verification: from the client under Firestore rules. Other admin-only RTDB writes: through function REST. The unverified `firebase_admin` (appsup) lead is dropped.

## Push notifications

`firebase_messaging` 17.0.0 describes itself as delivering messages on Android and iOS, and the investigation found no Windows or Linux support [V-26][U]. On those platforms notifications are **in-app only**, via RTDB `/inbox/$uid` (P14), which desktop clients listen to live. Mobile and web push go through the push function.

## App Check (Fixed: B4, option A)

Ruled by R 2026-10-20 (B4). **No App Check enforcement in v1.** Enforcement rejects every request without a valid App Check token [V-37], and there is no App Check for Linux or `firebase_dart` [U], so enforcing would lock out desktop. Protection in v1 comes from Auth plus RTDB and Firestore rules. App Check runs **monitor-only** on mobile and web (`firebase_app_check` 0.5.0 lists Windows, but official docs do not [V-26][U]). Revisit if abuse appears.

## Payments (deferred: concern 6)

Payments are a backend role (Fixed). R deferred the payment design: no provider is decided, and payment and store policy was not researched. The app keeps an `Entitlements` read model fed by claims, and the payment webhook and store-receipt functions stay as placeholders. **Probe 8.8** (provider plus app-store policy) is scheduled when R wants monetization designed, likely with D. Listed in [09-open-decisions.md](09-open-decisions.md#concerns-raised).

## Environments (Fixed: P10b)

Ruled by R 2026-10-20 (P10b). Three Firebase projects: **dev, staging and prod**. RTDB rules and Firestore rules (and functions) are tested in the Local Emulator Suite, as Firebase's security checklist recommends [V-19]. Desktop clients need network access to `*.firebaseio.com`, `*.firebasedatabase.app`, `identitytoolkit.googleapis.com`, `securetoken.googleapis.com` and `firestore.googleapis.com` (allowlist used by the probes) [U].

## Probe order (Fixed: B2)

Ruled by R 2026-10-20. Credentialed probes can run in the cloud or on R's PC. Full status and evidence paths: [verification.md](verification.md#probe-status).

| Order | Probe | Status |
|---|---|---|
| done | FS2 Firestore REST write and `runQuery` under rules, Windows and Linux | Done [V-32] |
| done | FS2 claim rules and composite index, Linux | Done [V-43] |
| done | FS2 natural token expiry and auto-refresh, Linux | Done [V-45] |
| done | 8.1b functions read/write RTDB over REST, callable by URL (FS3, B6) | Done [V-33] |
| done | FS3 least IAM role for RTDB from functions | Done by impersonation [V-46]; not run from a deployed function |
| done | B5 token storage and secure store, Linux and Windows | Done [V-34][V-35][V-44] |
| 1 | 8.6 RTDB rules prototype | Done in the emulator [V-38]; P10c ruled (see above) |
| 2 | 8.5 anonymous upgrade, Windows and Linux | Done [V-39] |
| 3 | 8.3 real custom token, Windows and Linux | Done [V-41] |
| 4 | 8.4 custom-claim pickup | Done on Linux [V-42]; Windows not run |
| 5 | 8.1 queued write across app restart, Windows and Linux | Done: write lost, outbox required [V-40] |
| later | 8.1c, 8.7, Storage via `firebase_dart`, long sessions | Not scheduled |
