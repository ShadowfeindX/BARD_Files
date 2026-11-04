# 06. Accounts and backend

## Backend role

Accounts, session persistence and relay, rules pack distribution, information dissemination (news, creative-director announcements), payments. The backend **never runs game rules**: no backend code imports the engine (see dependency rules in [00-overview.md](00-overview.md#dependency-rules)).

## Stack

The stack follows the backend-split investigation (project library: `architecture/backend-split.md` and its review). Firebase is preferred, with the Firebase console as the admin tool for D and content auditors. Data is split between two databases: RTDB for live play, Firestore for data at rest (see [Firestore](#firestore)).

| Layer | Choice | Notes |
|---|---|---|
| Client SDK | `firebase_dart` 1.6.2 (Auth, Realtime Database, Storage) as the adapter wherever it runs. Not built ([10 §5](10-waiting-on-d.md#5-workstream-rows-still-to-schedule)): `packages/backend` has no `firebase_dart` dependency today. Auth and RTDB probed [V-21]; Storage **not yet probed** | FlutterFire where `firebase_dart` cannot run (web), including `cloud_firestore` for Firestore on web |
| Live game data | **Firebase Realtime Database (RTDB)**: relay, active episode events, requests, members, phone, signaling, presence, head while active, inbox | Live play only |
| Data at rest | **Cloud Firestore**, Standard edition: archived episodes, library, pack index, searchable account data | Desktop access through a hand-written REST client |
| Files | Cloud Storage for Firebase (rules pack files) | Uploads by D through the console. Client Storage access through `firebase_dart` is unproven ([still unproven](09-open-decisions.md#still-unproven)) |
| Server code | **HTTPS-only Dart Cloud Functions** (experimental) [V-23] | Function list under [Cloud Functions](#cloud-functions) |
| Hosting | Firebase Hosting (web build) (planned) | — |
| Cloud Run | No separate service planned | Dart functions themselves deploy to Cloud Run [V-33] |

Platform targets in v1: **Windows and Linux desktop**, plus the web player build. macOS and iOS are not in v1. `firebase_dart` was probed on Windows and on Linux with identical results [V-21], and every later client probe ran on both [V-39]–[V-41][V-44] except 8.4 [V-42] and the Firestore claims/index follow-up [V-43] (Linux only), and natural expiry [V-45] (Linux only). Android was not probed.

### Backend port and adapters

`session` talks to the backend only through a **backend port** with these capabilities: auth, tree store (RTDB-shaped reads/writes with rules), event stream (live listeners), blob fetch (Storage), and a **document store** (Firestore: get, set, query, paged reads). Implementations live in the `backend` package:

| Adapter | Used on | Built on |
|---|---|---|
| `FirebaseDartAdapter` | Windows and Linux (probed) | `firebase_dart` for Auth, RTDB, Storage; the hand-written Firestore REST client (below) for the document store |
| `FlutterFireAdapter` | where `firebase_dart` cannot run (web) | FlutterFire plugins, including `cloud_firestore` |
| `LanAdapter` | LAN/in-person play with no backend | session transports |

Not built ([10 §5](10-waiting-on-d.md#5-workstream-rows-still-to-schedule)): `packages/backend` holds only a stub today, so none of these adapters or the Firestore REST client exist yet. Swapping adapters never touches session or engine. FlutterFire `cloud_firestore` 7.0.0 failed to link on Windows in the probe [V-22], which is why desktop does not use it.

### Firestore

Firestore runs alongside RTDB. The split avoids database migrations for large structural changes or format additions, moves infrequent operations to an API that supports them, and makes Firestore querying more efficient for GMs and users searching past operational data, items, archives and packs.

**Split.**

| Store | Holds |
|---|---|
| RTDB (live play only) | Active episode events, requests, members, phone, signaling, presence, head snapshot while active, inbox |
| Firestore (data at rest) | Archived episodes (frozen event log, text log, final head snapshot), library (pending and public), pack index (pack files stay in Storage), searchable account data (profiles, aliases, campaigns, news) |

**Desktop client.** Not built ([10 §5](10-waiting-on-d.md#5-workstream-rows-still-to-schedule)). No Firestore SDK runs on desktop. `backend` will contain a small hand-written Firestore REST client behind the backend port; it calls `getIdToken()` on `firebase_dart` for every request and sends the token as a Bearer header, and Security Rules authorize the request [V-36]. Web uses FlutterFire `cloud_firestore`. Probed on Windows and Linux [V-32]: PATCH write 200, `runQuery` with filter, `orderBy` and `limit` 200, rules enforced (403 on a denied path and with no token), `getIdToken(true)` refresh works, a bad token gives 401.

Follow-up probe [V-43]: a query that needs a composite index returns 400 `FAILED_PRECONDITION` ("The query requires an index") until the index is READY, then 200; a rule on a custom claim (`request.auth.token.role == 'gm'`) gives 403 without the claim and 200 once the claim is set and the token force-refreshed. So the REST client (Proposed, open: [06-O1](09-open-decisions.md#06-o1-firestore-rest-client-token-handling)):
- surfaces `FAILED_PRECONDITION` as a missing-index error (a deploy problem, not a user error); every query the app runs has its composite index declared with the Firestore collection draft;
- forces `getIdToken(true)` after a role change before relying on a claim (see [Roles](#roles)).

**Natural expiry** (Linux, `firebase_dart` 1.6.2, session restored from storage in a second process [V-45]): a stale ID token gets 401 from Firestore REST, and a plain `getIdToken()` after expiry returns a new working token by itself. The REST client calls `getIdToken()` for **every request**. Proposed (open: [06-O1](09-open-decisions.md#06-o1-firestore-rest-client-token-handling)): it never caches the token string, and on a 401 it retries once with `getIdToken(true)` before surfacing a sign-in error. Not tested: revoked sessions, disabled users, password change, refresh-token failure, Windows [V-45].

**Search.** Standard edition: structured queries (equality, range, array-contains on keyword and tag fields), with composite indexes where needed. No full-text search. Text search needs an Enterprise edition database [V-36]. Standard bills per document read [V-36].

**Document sizing** (Planned; 10 §5 'Cloud Functions: badge login, roles, push...' row). Archived event and text logs are chunked into a subcollection (one document per N batches), never one document per episode, to stay under the 1 MiB document cap [V-7]. A function wrote and read back a chunk of about 920 KiB (900 items) through `firebase_admin_sdk` [V-33].

**Firestore collections** (collection names, document shapes, rules, indexes) are drafted in [12-firestore-collections.md](12-firestore-collections.md) (Proposed, open: [S-7](09-open-decisions.md#s-7-firestore-collections)). RTDB rules are tested in the Emulator Suite. The Firestore rules are to be tested in the Emulator Suite; the tests are still to be written (open: [S-7](09-open-decisions.md#s-7-firestore-collections)).

## Account model

The field-level shapes are Proposed (open: [S-7](09-open-decisions.md#s-7-firestore-collections)).

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
  ├─ members: player accounts (invited and managed at campaign level)
  ├─ personas[]          Handler personas, owned by the campaign
  ├─ packRefs            the pack version pin
  ├─ baseSettings        copied into each new mission
  └─ operations[]
```

- **Handler personas.** A persona is a character-shaped entity owned by the campaign, not tied to the GM's account. It has the same components as an alias, with stats set by the GM; the GM uses them when a player asks that Handler for help. Inside an operation the roster shows the persona, never the GM account; players see the GM account only when accepting a campaign invite. Moving a persona to another campaign is a copy (Proposed, open: [FE-L3](10-waiting-on-d.md#fe-l3)). Not built: see the Handler persona entity (R-A4) row in [10 §5](10-waiting-on-d.md#5-workstream-rows-still-to-schedule). The document shape is a later row ([12](12-firestore-collections.md#campaigns-operations-and-episodes)).

Profiles, aliases and campaigns are searchable account data and live in Firestore. Field-level shapes are in [12-firestore-collections.md](12-firestore-collections.md) (Proposed, open: [S-7](09-open-decisions.md#s-7-firestore-collections)).

Rules:

- An alias is locked to one campaign. **Transfers:**
  - The **destination** campaign's GM approves a transfer.
  - The **source** campaign is notified; it does not consent.
  - An alias in a **running episode cannot move** until that episode ends.
  - The transfer request is a Firestore document under the destination campaign, approvable only by its GM (Firestore rules).
- **Anonymous accounts:** can join any episode, have exactly one alias, cannot GM, host or create content. They may browse the free (level-1) library entries like a free account; they still have no voice, video or messaging. Anonymous sign-in works in `firebase_dart` on Windows and Linux [V-21].
- **Upgrading an anonymous account** (probe 8.5, Windows and Linux [V-39]). `linkWithCredential` is an `UnimplementedError` stub in `firebase_dart` 1.6.2 [V-39], and signing in with email after anonymous gives a **new** uid [V-21], so neither can carry the account over. Proposed upgrade path (open: [06-O2](09-open-decisions.md#06-o2-anonymous-to-full-account-upgrade)):
  - Call `updateEmail` then `updatePassword` on the signed-in `firebase_dart` user. This keeps the uid, clears `isAnonymous`, and later email sign-ins return the same uid [V-39].
  - Do not call the Identity Toolkit `accounts:update` REST endpoint out of band for this. It also keeps the uid, but it leaves `firebase_dart`'s stored session inconsistent (Linux: `reload()` fails with `user-token-expired`; Windows: `reload()` still reports anonymous) [V-39].
  - Map `EMAIL_EXISTS` and `WEAK_PASSWORD` to user-facing messages [V-39].
  - After upgrading, force `getIdToken(true)` before any host, GM or content command: the token issued before the upgrade still says `sign_in_provider: anonymous` (decoded, not re-verified) [V-39], and the rules refuse anonymous tokens for those writes (shown in the emulator with hand-built tokens [V-38]).
  - The upgraded account has `email_verified: false` [V-39]; whether hosting needs a verified email is open ([06-O2](09-open-decisions.md#06-o2-anonymous-to-full-account-upgrade)).
- Anonymous data does not survive clearing local storage or switching devices [V-8]; the UI says so before an anonymous player invests in a character.
- Enforcement: the session refuses host and GM commands from anonymous agents (content creation is planned, 10 §5), and RTDB rules refuse the corresponding writes using `auth.token.firebase.sign_in_provider` (built as a prototype, [V-38]; claim values [V-9]); Firestore rules are planned (open: [S-7](09-open-decisions.md#s-7-firestore-collections)). The RTDB rules prototype refuses `meta`, head and event writes from anonymous tokens in the emulator [V-38]; live tokens carry the values the rules check (`anonymous`, `password`, `custom`) [V-39][V-41]. Rules on the deployed database are not tested yet.
- **One alias per anonymous account** is to be enforced in three places; the session layer is built (`episode_host_test.dart`):
  1. **Backend.** The rule lives in Firestore. Proposed mechanism (open: [S-7](09-open-decisions.md#s-7-firestore-collections)): an anonymous account's alias is a single fixed-key document, creatable only when it does not already exist, so a second alias is impossible. Full accounts use generated ids. The document path is `aliases/{uid}/items/anon` with the rule in [12-firestore-collections.md](12-firestore-collections.md#aliases-characters) (rule behaviour unproven until the Emulator Suite tests).
  2. **App.** The account repository hides "create alias" for anonymous agents once that alias exists and offers the upgrade instead.
  3. **Session (local and LAN play without the backend).** A guest agent identity carries `kind: anonymous`; `EpisodeHost` refuses a `hello` that presents a second alias for the same anonymous agent id.

## Roles

Admin, moderator and payment tier are **custom claims** on the Auth token, set by the roles Cloud Function (planned, 10 §5) with `firebase_admin_sdk` (which supports `setCustomUserClaims`) [V-24]. Rules read them from `auth.token` [V-9]: shown for Firestore rules [V-43], not yet tested in RTDB rules. In probe 8.4 a forced `getIdToken(true)` showed a new claim about 37 s after polling started (including a manual step), and so did `reload()`; the plain `getIdToken()` never did within the 4-minute window [V-42] (Linux only; Windows not run).

Design (Proposed, open: [06-O3](09-open-decisions.md#06-o3-claim-pickup-after-a-role-change)): when the roles function changes a claim, it also writes an inbox notice to `/inbox/$uid` (planned, 10 §5); the client that receives it calls `getIdToken(true)` and reloads its `Entitlements` read model. Whether a client that never gets the notice picks up the claim when its token next refreshes on expiry is **untested**: V-45 shows the token refresh, not claims, and in V-42 the plain `getIdToken()` did not show the claim while the old token was still valid.

## Badges

A badge is a printable/scannable code on a physical agent badge that signs an agent in. It depends on probe 8.3, which **passed** on Windows and Linux [V-41].

- **Sign-in path:** scanning sends the badge credential to the **badge-login HTTPS Dart function** (planned, 10 §5), which verifies it and returns a custom token minted with `firebase_admin_sdk` `createCustomToken` [V-24]; the app signs in with `signInWithCustomToken`. Firebase rules see `sign_in_provider == "custom"` [V-9][V-41]. Developer claims put in the token at minting survive a forced refresh [V-41].
- **Symbology:** PDF417, not QR.
- **Payload:** only the badge id and a 256-bit secret (about 70 ASCII characters). The secret is stored **hashed**; the badge is revocable and never carries a password.
- **Evidence:** a malformed custom token is rejected with `invalid-custom-token` [V-21]. A token minted in a deployed function (`createCustomToken`, no key file) signed in via `firebase_dart` on Linux once the runtime service account held Service Account Token Creator [V-33]. A real custom token (minted with `gcloud iam service-accounts sign-jwt`) signed in on **Windows and Linux** [V-41]. The badge function and the flow end to end are not built yet.
- **Deploy checklist:** grant **Service Account Token Creator** (`roles/iam.serviceAccountTokenCreator`) to the function's runtime service account on itself; without it `createCustomToken` fails with `iam.serviceAccounts.signBlob` denied [V-33].
- **Packages (no package is added before R approves it; Proposed, open: [S-8](09-open-decisions.md#s-8-badge-packages)):** printing (candidate `barcode`), phone scanning (`mobile_scanner`), desktop scanning (`flutter_zxing`, Windows/Linux beta, or USB 2D keyboard-wedge scanners). Each is proposed with its purpose and alternatives when badges are scheduled.
- Badges are optional, per agent, listed and revocable from account settings.
- Offline: a badge cannot create a new sign-in without the backend. An agent already signed in on that device keeps working from the local cache (planned; 10 §5 'Offline account cache and session outbox').

## Offline accounts

A signed-in account works offline from a local cache. The app keeps its own local record (profile, aliases, campaigns, packs by content hash, episode logs) in the local store (sembast; not built; 10 §5 'Offline account cache and session outbox'; see [04-session.md](04-session.md)).

`firebase_dart` does **not** keep pending writes across a restart. Probe 8.1 on Windows and Linux [V-40]: a write queued while offline is readable locally, but after the app exits or is killed and restarts, it is gone from the server and from the local cache. A write that reached the server before the restart is still in the local cache afterwards. Within one process, a write queued with `goOffline` is delivered on `goOnline` [V-21].

So the session's **outbox is required**: requests made offline are stored in the local store (sembast; not built; 10 §5 'Offline account cache and session outbox') and replayed as ordinary requests on reconnect; the GM stays canonical, so replay is safe (dedupe by request id, [03-protocol.md](03-protocol.md#ordering-and-delivery)). The app never relies on the SDK's offline queue to carry a write past the end of the process.

### Auth token storage

Not built ([10 §5](10-waiting-on-d.md#5-workstream-rows-still-to-schedule)): `hive` 2.2.3 (pinned), `flutter_secure_storage` and the box encryption below are not in any pubspec yet; this section is the target design.

By default `firebase_dart` 1.6.2 stores the refresh token and email in plaintext in the Hive box `firebase_auth`, and `FirebaseDart.setup` has no storage option [V-34]. The design:

- After `FirebaseDart.setup` and **before any `FirebaseAuth` use**, `backend` opens the Hive box `firebase_auth` with `HiveAesCipher(key)`. That encrypts the box [V-34].
- The key lives in the OS secure store via `flutter_secure_storage` 11.2.0. Linux: libsecret (Secret Service) [V-34]. **Windows: not Credential Manager**, but a JSON file of DPAPI-protected values at `%APPDATA%\<company>\<product>\flutter_secure_storage.dat` (`flutter_secure_storage_windows` 4.2.2), tied to the Windows user account [V-44]. The folder follows the app's Windows company and product names, so the Windows runner sets them deliberately before the first release; renaming them later orphans the key (key loss, below).
- **Guard 1, key access and migration.** Reading or creating the key never fails silently: a wrong or missing key makes Hive truncate the box and sign the user out, on Linux and Windows alike [V-34][V-44], so a key failure is surfaced, not swallowed. **Key loss means no session** [V-44]. Requirement: the app shows that the user must sign in again and does not treat it as an error loop. A plaintext-to-encrypted migration step handles boxes written before encryption: it reads the plaintext box before any encrypted open, then rewrites it encrypted. Opening an existing plaintext box with the cipher was not probed, so the migration is tested before release.
- **Guard 2, locked keyring.** On Linux a locked keyring with no prompter blocks the libsecret call forever and freezes the event loop [V-34], so key access runs under a timeout guard and reports instead of hanging. A missing Secret Service gives a clean error [V-34]. Windows showed no hang [V-44]; the guard stays on every platform.
- **Dependency:** `hive` 2.2.3 is a direct dependency of `backend`, **pinned exactly**. It must be the same `hive` package `firebase_dart` uses (`hive` ^2.0.0, not `hive_ce`) [V-35].
- **Known risk:** `firebase_dart` depends on `hive`, which has had no release since 2.2.3 (2022-06-30) [V-35], and on `firebaseapis` 0.2.0, whose repository was archived on 2026-03-24 (per the backend investigation, project library `architecture/firebase-desktop-deep-dive.md`).
- Not tested: KWallet (no Secret Service bridge).

## Realtime Database model (live play)

The design comes from probe 8.6, whose rules pass 116 of 116 checks in the Emulator Suite [V-38]. The rules file is in the repository at `firebase/database.rules.json`. Its emulator checks are in `firebase/rtdb_rules_test/` ([08-testing.md](08-testing.md#backend); how to run them: `firebase/README.md`). They pass 200 of 200 in the Emulator Suite, including the post-archive clean-up [V-50], the presence, `meta` validation and anonymous-member rules [V-51] and the follow-up checks [V-52] (see [Rules behavior](#rules-behavior)). The live tree is `/episodes/$ep` (with `/presence/$ep`); the suite passes 200 of 200 on these paths [V-56]. RTDB keeps **live play only**; everything at rest is in Firestore (collections drafted in [12-firestore-collections.md](12-firestore-collections.md), Proposed, open: [S-7](09-open-decisions.md#s-7-firestore-collections)).

```
/episodes/$ep/meta                      gm uid, campaignId, engine version, packRef, status (required string), locked (boolean; once set, never removed), lastSeq
/episodes/$ep/members/$uid              { aliasId, joinedAt }; written by the GM client only (membership moves to the campaign in a later change; the rules change goes through the Opus gate; workstream row: 10-waiting-on-d.md section 5)
/episodes/$ep/requests/$uid/$push       { id, kind, from == $uid, ... }; the member writes own uid only, create-only
/episodes/$ep/events/$audience/$push    { seq, body }; GM only; create-only; .indexOn seq
/episodes/$ep/textlog/$audience/$push   { seq, text }; GM only; create-only; .indexOn seq
/episodes/$ep/head                      head snapshot; GM only (read and write)
/episodes/$ep/phone/$uid/$push          phone box per player: player and GM messages; the player writes own box (from == $uid), the GM writes any box; { from, text } with text at most 2,000 UTF-16 units (field names are the implementation's choice); cleared when the operation ends
/episodes/$ep/signaling/$uid/...        WebRTC offer/answer/candidates (P2P mode only); written by that uid or the GM; frozen by locked [V-50]
/presence/$ep/$uid                      own presence; members write own uid until the episode is archived; members and GM read
/inbox/$uid/$push                       in-app notifications; owner reads and deletes; only functions write
```

`$audience` is `gm`, `public` or `alias:<aliasId>`, checked by a `.validate` pattern [V-38].

Who can do what (shown in the emulator [V-38]; the `meta` and `signaling` rules are shown by the repository's rules checks [V-50]):

| Path | GM | Member (player) | Others |
|---|---|---|---|
| `meta` | creates it (non-anonymous, naming itself `gm`), edits until locked; `gm` cannot change; never deletes, and every write keeps `gm` as the writer [V-50]; `status` cannot be removed and `locked` must be a boolean [V-51] and once set is never removed [V-52] | reads | — |
| `members` | reads all, writes entries until locked | reads own entry only, cannot list | — |
| `requests` | reads and clears | creates under own uid with `from == auth.uid`; cannot read requests at all, own included | — |
| `events`, `textlog` | reads every audience; appends, never overwrites or deletes | reads `public` and `alias:<own aliasId>` only | — |
| `head` | reads and writes until locked | — | — |
| `phone` | reads every box, delivers into any box | reads own box, appends to it (create-only: no client edits or deletes a message); anonymous members read only their own box [V-51]; messages need string `from` and `text` of at most 2,000 UTF-16 units (field names are the implementation's choice) [V-52] | — |
| `signaling` | reads (as probed); writes any uid's branch until locked | reads (as probed); writes own uid's branch until locked; anonymous members cannot read or write [V-51][V-52] | — |
| `presence/$ep` | reads (writes own uid only if also a member) | reads; writes own uid until `meta/status` is `archived` [V-51] | — |
| `inbox/$uid` | — | owner reads and deletes | functions write (admin REST) |

After `meta/locked = true` the GM cannot append, write head, add members or unlock, and members cannot write requests or phone [V-38]; signaling is frozen too [V-50]; presence stays writable while the lock holds (the post-archive clean-up below then deletes it and closes it), and the inbox is written only by functions, so the lock does not affect it; reads continue. Anonymous accounts can be members and write requests, and cannot create episodes, write GM-only paths, send phone messages or write signaling (no voice or video) [V-51].

Design notes from probe 8.6:

- **Phone is a per-player box** (`phone/$uid/$push`). A client can list only paths it can read, so the box is per player [V-38]. Phone messages remain engine events (`PhoneMessageSent`, see [04-session.md](04-session.md#in-game-phone)). **Box contents and lifetime.** GM messages go into the box as well. The box clears when the operation ends. The `PhoneMessageSent` events in the audience branches stay the record, and a function clears the box with admin REST after the archive is written, because the phone write rule is create-only (`!data.exists()`), so no client can delete a message [V-38]. Size: about 12 KB per 4-hour session at the assumed profile (an approximation, not a measurement), so no storage concern (project library `architecture/rtdb-traffic-cost-estimate.md`, flag 1).
- **The GM's read sits on each parent** (`members`, `requests`, `events`, `textlog`, `phone`). Read rules cascade downward, so child rules only handle players [V-38].
- **Resync indexes:** `events/$audience` and `textlog/$audience` declare `.indexOn: ["seq"]`; `orderBy="seq"&startAt=N` and `limitToLast` then work for members. Catch-up by key needs no index (as in [V-33]). An unindexed `orderBy` is refused with 400 on REST [V-38].
- **Refusals are indistinguishable.** A failed `.validate` returns the same 401 `Permission denied` as an unauthorized write, so the client logs the refused payload locally to tell the two apart in debugging [V-38].
- **Rules do not check `seq` order or gaps.** That stays the GM client's job; rules only require a numeric `seq`, create-only keys and a valid audience [V-38].
- **The one-alias rule is not in RTDB.** It is in Firestore ([12](12-firestore-collections.md#aliases-characters), Proposed, open: [S-7](09-open-decisions.md#s-7-firestore-collections)); RTDB only checks that a member entry carries one `aliasId` [V-38].
- **Lookups per evaluation** are at most 3 `root.child` reads, under the limit of 10 the probe write-up cites for RTDB rules [U] (a static count, not a load test) [V-38].

### Rules behavior

Shown by `firebase/database.rules.json` and its emulator checks [V-50]–[V-54] ([08-testing.md](08-testing.md#backend)); deployed rules with real signed tokens are still untested.

1. **No delete on `meta`.** If the GM could delete `meta` of an unlocked episode, any full account could recreate it naming itself GM. So `meta` cannot be deleted; status and lock are edited, never removed. Every `meta` write must leave `gm` equal to the writer, so deleting `meta` or `meta/gm` is refused; the lock then refuses all `meta` writes. [V-50]
2. **Signaling keyed by uid.** If any member could overwrite any `signaling/$peer`, they could overwrite another player's offer. So signaling lives under `signaling/$uid/...`, written only by that uid or the GM. Read scope is members and the GM, narrowed so anonymous members cannot read it. Only matters for P2P mode, which is built last. [V-50]
3. **Lock freezes signaling.** `meta/locked = true` also freezes signaling writes. Presence stays writable under the lock until the post-archive clean-up deletes it; the inbox is written only by functions, so the lock does not touch it. [V-50]
4. **Presence closes once archived.** The archive step sets `meta/status` to `archived` and the post-archive clean-up deletes `presence/$ep`; presence writes are refused while `meta/status` is `archived`. The marker value `archived` is the rules file's choice (status values are otherwise not defined yet). [V-51]
5. **`meta` validation.** `meta` must carry `gm` and `status`; `status` is a string and cannot be removed; `locked` must be a boolean. [V-51]
6. **Anonymous members do not message or signal.** An anonymous (clearance 0) member cannot read or write signaling, so cannot join voice or video, and cannot send phone messages; they can still read their own box, write requests and write presence. Age verification happens at account creation, so only full accounts message. [V-51]
7. **Archive order:** lock, then archive, then clean-up (see "Archiving" below). [V-52]
8. **Phone message shape:** each message carries string `from` and `text`; `text` is at most 2,000 UTF-16 units, for GM and player messages alike. The field names are the rules file's choice until the phone message payload is drafted. [V-52]
9. **`locked` is never removed:** once `meta/locked` exists it cannot be deleted, before or after the lock, so before the lock it can only be set to `true` or `false`, and after the lock it cannot change at all. [V-52]
10. **Non-member reads of the text log** are refused (root, `gm` and `public` branches), including `textlog/alias:null`, mirroring the events check [V-52]; the `alias:null` read is shown by [V-53].
11. **`archived` is admin-only:** the rules refuse `meta/status = archived` from any client, the GM included, before or after the lock (also when the whole `meta` is replaced). Only the archive step (admin REST) sets it. After the lock, status cannot change at all [V-53].
12. **Phone length unit:** the 2,000 limit is checked with the rules language's `.length`, which counts UTF-16 code units, so an emoji can count as 2 (1,000 emoji are accepted, 1,001 refused). Shown in the emulator; the unit (not the 1,000/1,001 boundary) was confirmed on a real RTDB test project with short strings [V-55]. The limit is a size bound, not a character count.
13. **Multi-path writes:** the emulator runs PATCH writes that change several paths at once (on the episode node and from the root), and PUT and DELETE of the whole episode node, before and after the lock. Archived-status, `meta` delete and unlock refusals hold, and a write refused before the lock is rolled back as a whole (head and event stay unwritten). A PUT or DELETE of the whole episode node is refused only because that node has no write rule; the body is not evaluated [V-54].

Not covered by the probe (carry to implementation): rules deployed to a real project with signed tokens, custom claims in RTDB rules, member removal, payload size limits, load, and `firebase_dart` listeners against these rules [V-38].

Account data (`/users`, aliases, badges, `/campaigns` and transfers, `/packs`, `/archive/pending`, `/archive/public`, `/news`) is in Firestore; paths are drafted in [12-firestore-collections.md](12-firestore-collections.md) (Proposed, open: [S-7](09-open-decisions.md#s-7-firestore-collections)).

Notes on the live tree:

- **Per-audience branches.** RTDB rules grant reads per path, so the GM reads everything, members read `public`, and an alias owner reads only their own branch. GM-only events and text are never stored where a player can read them.
- **Head snapshot.** Planned (the local store is not built, 10 §5). Non-web hosts write the head snapshot to the local store with every batch. It is **mirrored to RTDB on the GM-configurable per-episode interval** ([04-session.md](04-session.md)); events and text go to RTDB every batch.
- **Joins** (Planned; 10 §5 'Campaign-level members and rules' row). Join requests are answered by the GM client, which writes `members/$uid` under RTDB rules [V-38]. Players are invited and managed at the campaign; the Handler picks which characters join which missions.
- **Retention.** Once a mission is marked complete or submitted, all of its session data other than the latest snapshot is removed ([12](12-firestore-collections.md#archives); open: [FE-L4](10-waiting-on-d.md#fe-l4)). Until then each episode's archive and snapshot are kept so the Handler can roll back. Not built: see the Snapshot pruning (R-A3) row in [10 §5](10-waiting-on-d.md#5-workstream-rows-still-to-schedule).
- **Archiving.** Planned (the `archiveEpisode` function and the clean-up are not built, 10 §5). The order is lock, archive, clean-up. The GM client first sets `meta/locked`, which rules check [V-38], so nothing more can be written to the events, textlog, head, requests, phone or signaling branches once the log is frozen (presence stays writable under the lock); then the `archiveEpisode` function (below) copies the frozen log to Firestore; then the clean-up below runs. The lock cannot be undone, so a failed archive write is retried against the locked data; until a retry succeeds the locked episode stays in RTDB with its status unchanged, so nothing is lost; the archive step sets `archived` and the clean-up runs only after the archive write is confirmed. Archived logs are chunked into a Firestore subcollection. Migrated episodes get a new id; the genesis event lists the archives ([05-migrator.md](05-migrator.md#archived-logs)). **Clean-up after archive:** once the archive write is confirmed, a function deletes the live branches (`events`, `textlog`, `requests`, `head`, `signaling`, `presence`) with admin REST and keeps `meta` and `members` as the locked stub (`meta` is never deleted). The phone box is cleared at operation end; not built yet (workstream row: [10](10-waiting-on-d.md#5-workstream-rows-still-to-schedule)). Until then the box stays with the locked stub. Admin REST bypasses rules, so the clean-up needs no rule; the checks show `meta`, `members` and `phone` remain, `meta` stays locked, members can still read it [V-50]; `phone` remaining and a player still reading their box are shown by [V-56]. The archive step sets `meta/status` to `archived` with admin REST, after the lock and before the clean-up deletes anything, and the rules then refuse presence writes, so a member's client cannot recreate presence after the clean-up [V-51]. Only admin REST can set that value: the rules refuse `archived` from any client, the GM included, before or after the lock [V-53]. An episode that is never archived needs a manual clean-up script, because deployed Dart functions have no scheduled triggers [V-23].
- **Scale.** RTDB's docs give about 200k simultaneous connections per database and about 1,000 writes per second per database, with multiple databases available on the Blaze plan [V-25]. Index nodes are denormalised so clients never scan large branches. Traffic and cost at an assumed table size are approximated in the project library (`architecture/rtdb-traffic-cost-estimate.md`): about 2,200 writes per 4-hour session (an approximation from an assumed profile, not a measurement), about 0.15 writes per second.

## Library

Not built ([10 §5](10-waiting-on-d.md#5-workstream-rows-still-to-schedule)). The library is the government-style public archive of verified items. It lives in Firestore with `pending` and `public` collections (names drafted in [12](12-firestore-collections.md#library-packs-and-listings): `libraryPending`, `libraryPublic`, `libraryData`; Proposed, open: [S-7](09-open-decisions.md#s-7-firestore-collections)).

- Submissions land as pending items.
- **Verification claim: R and D only**, at first. It is set by the roles function; more auditors are added later through the console. Revocable.
- Verification is a client write under **Firestore rules**: a reviewer holding the claim moves an item from pending to public. A function is added only if the rules get awkward.
- The record keeps **verifier, date and version**.
- **Revocation** puts the item back to pending with a reason; copies already in GM packs are unchanged.

## Packs

Not built (10 §5). The pack index (id, version, content hash, Storage path) is in Firestore; pack files stay in Cloud Storage and D uploads through the console. Clients validate packs with the engine on load ([02-rules-packs.md](02-rules-packs.md#loading-and-validation)). The pack publishing helper function (planned, 10 §5) assists with index plus Storage.

## Relay

Planned (the relay is not built; 10 §5 'RTDB live relay'). In network-hosted mode the backend relays and persists. With this stack the live relay **is RTDB**: the GM writes event batches under `/episodes/$ep/events`, participants listen; players write requests under their own uid, the GM listens. A listener on a second client instance received writes in the probe, with reads and writes around 50 ms [V-21]. No custom relay server. Once an episode is archived, its log is read from Firestore.

## Cloud Functions

Dart Cloud Functions are experimental and may change without notice. They require enabling the `dartfunctions` experiment in the Firebase CLI, the Blaze plan, Dart 3.9+ and a recent CLI. In production only HTTP (`onRequest`) and callable (`onCall`, including `onCallWithData`) triggers can be deployed; other triggers run only in the emulator, so there are no deployed database, storage, scheduled, Pub/Sub, Auth-blocking or task-queue triggers. Dart callables cannot be called by name from client SDKs, only by their full URL, and the Firebase console does not display Dart functions (they appear in the Cloud console) [V-23].

Planned: none of these functions exist yet ([10 §5](10-waiting-on-d.md#5-workstream-rows-still-to-schedule)).

| Function | Does |
|---|---|
| Badge login | Verify badge id and secret (hash compare), `createCustomToken` |
| Roles | Set admin / moderator / tier custom claims, including the library verification claim (token key `arbiter`) |
| Payment webhook | **Placeholder** until payments are designed (see [Payments](#payments)): receive the provider's webhook (`onRequest`), set the tier claim |
| Store receipts | **Placeholder** until payments are designed: validate app-store receipts [U] |
| Pack publishing helper | Assist publishing a pack version (index + Storage) |
| Push | Mobile/web push via `firebase_admin_sdk` Messaging [V-24] |
| `archiveEpisode` | Called by the GM client with the frozen event log, text log and final head; validates the shape and writes the archive to Firestore (chunked) via `firebase_admin_sdk`. The GM client sets `meta/locked` before calling it; the clean-up follows a confirmed write |

### Calling functions from desktop

Desktop calls a callable by its full URL with `POST`, `Authorization: Bearer <Firebase ID token>` and the body envelope `{"data": ...}`; success is `200 {"response": ...}`. Probed on Windows and Linux: 200 with the handler seeing the caller's `request.auth.uid`; a bad token gets 401 from the framework; with no token the framework did not reject (the handler saw no auth, so each handler must check `request.auth` itself) [V-33].

### Function credentials and RTDB access

Probe evidence is in [V-33]. The planned function dependencies are `firebase_admin_sdk` 0.5.6 and `firebase_functions` 0.8.0 (today `apps/functions` depends only on `protocol_envelope`). `firebase_admin_sdk` has Auth, Messaging, Storage, App Check, Firestore, Functions and Security Rules libraries but **no** Realtime Database library [V-24]. So:

- **Firestore** writes (such as the archive) go through `firebase_admin_sdk`; a chunk of about 920 KiB was written and read back [V-33].
- **RTDB** reads and writes from a function are the function's **own REST calls** using the runtime's **default credential**: no key files and no scope handling. The probe wrote and read RTDB this way [V-33].
- **Scoping:** requests are admin (bypass rules) unless the call passes `auth_variable_override`, which switches the request to rules evaluation; the parameter is honored on REST [V-33]. Functions use it to stay scoped to rules where that is wanted. Whether an overridden uid is then allowed by a matching rule was not tested.
- **Service accounts:** each function group runs as a **dedicated runtime service account** (least privilege), not the default compute account. **Least IAM role for RTDB** [V-46]: `roles/firebasedatabase.admin` is the narrowest predefined role tested that gives RTDB REST read and write; `roles/firebase.viewer` gives read only (`roles/firebasedatabase.viewer` was not in the deciding run); `roles/firebase.admin` and `roles/editor` work but are broader. A custom role with only `firebasedatabase.instances.get` + `.update` is not enough, and the single permission that grants data access was not isolated. **Deploy checklist:** each function service account that reaches RTDB gets `roles/firebasedatabase.admin`; no narrower custom role is built. After creating a service account and granting Token Creator, allow 60-90 s before minting tokens [V-46]. Tested by impersonating a fresh service account, not from a deployed function running as it.
- **Custom tokens** need Service Account Token Creator on the runtime service account (see Badges).
- **No Node function is used.** Anything needing database, auth or scheduled triggers is designed out or done as a manual script.

**Who writes what.** Joins: written by the GM client under RTDB rules. Library verification: from the client under Firestore rules. Other admin-only RTDB writes: through function REST.

## Push notifications

`firebase_messaging` 17.0.0 describes itself as delivering messages on Android and iOS, and the investigation found no Windows or Linux support [V-26][U]. On those platforms notifications are **in-app only**, via RTDB `/inbox/$uid`, which desktop clients listen to live. Mobile and web push go through the push function (planned, 10 §5).

## App Check

There is **no App Check enforcement in v1**. Enforcement rejects every request without a valid App Check token [V-37], and there is no App Check for Linux or `firebase_dart` [U], so enforcing would lock out desktop. Protection in v1 comes from Auth plus RTDB and Firestore rules. App Check runs **monitor-only** (planned; 10 §5 'App Check monitor-only') on mobile and web (`firebase_app_check` 0.5.0 lists Windows, but official docs do not [V-26][U]). Enforcement is revisited if abuse appears.

## Payments

Payments are a backend role. The payment design is deferred: no provider is decided, and payment and store policy was not researched. The app keeps an `Entitlements` read model fed by claims (planned; not built, 10 §5), and the payment webhook and store-receipt functions stay as placeholders. **Probe 8.8** (provider plus app-store policy) is scheduled when monetization is designed, likely with D. Listed in [09-open-decisions.md](09-open-decisions.md#deferred).

## Environments

Three Firebase projects: **dev, staging and prod**. The RTDB rules are tested in the Local Emulator Suite; the Firestore rules and the functions are to be tested there (open: [S-7](09-open-decisions.md#s-7-firestore-collections) for the Firestore rules), as Firebase's security checklist recommends [V-19]. Desktop clients need network access to `*.firebaseio.com`, `*.firebasedatabase.app`, `identitytoolkit.googleapis.com`, `securetoken.googleapis.com` and `firestore.googleapis.com` (allowlist used by the probes) [U].

## Probe order

Credentialed probes can run in the cloud or on the project's Windows PC. Full status and evidence paths: [verification.md](verification.md#probe-status).

| Order | Probe | Status |
|---|---|---|
| done | Firestore REST write and `runQuery` under rules, Windows and Linux | Done [V-32] |
| done | Firestore claim rules and composite index, Linux | Done [V-43] |
| done | Firestore natural token expiry and auto-refresh, Linux | Done [V-45] |
| done | 8.1b functions read/write RTDB over REST, callable by URL | Done [V-33] |
| done | Least IAM role for RTDB from functions | Done by impersonation [V-46]; not run from a deployed function |
| done | Token storage and secure store, Linux and Windows | Done [V-34][V-35][V-44] |
| 1 | 8.6 RTDB rules prototype | Done in the emulator [V-38]; rules in place (see above) |
| 2 | 8.5 anonymous upgrade, Windows and Linux | Done [V-39] |
| 3 | 8.3 real custom token, Windows and Linux | Done [V-41] |
| 4 | 8.4 custom-claim pickup | Done on Linux [V-42]; Windows not run |
| 5 | 8.1 queued write across app restart, Windows and Linux | Done: write lost, outbox required [V-40] |
| later | 8.1c, 8.7, Storage via `firebase_dart`, long sessions | Not scheduled |
