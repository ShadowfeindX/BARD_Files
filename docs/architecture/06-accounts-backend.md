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

Platform targets: **Linux is required in v1** (R). `firebase_dart` was probed on Windows and on Linux (WSL2 Ubuntu) with identical results [V-21]. macOS, iOS, Android and web were not probed.

### Backend port and adapters (Fixed: P10a)

Ruled by R 2026-10-20 (P10a). `session` talks to the backend only through a **backend port** with these capabilities: auth, tree store (RTDB-shaped reads/writes with rules), event stream (live listeners), blob fetch (Storage), and a **document store** (Firestore: get, set, query, paged reads). Implementations live in the `backend` package:

| Adapter | Used on | Built on |
|---|---|---|
| `FirebaseDartAdapter` | Windows and Linux (probed); macOS and mobile expected but unproven | `firebase_dart` for Auth, RTDB, Storage; the hand-written Firestore REST client (below) for the document store |
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

Not proven by that probe (carry as open items for the REST client):
- natural token expiry and automatic refresh (only a forced refresh was tested);
- queries that need composite indexes;
- rules that depend on custom claims;
- macOS, iOS, Android (the probe covered Windows and Linux).

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
- **Upgrading an anonymous account:** `firebase_dart` has no `linkWithCredential` [U], and signing in with email after anonymous produced a **new** uid in the probe [V-21]. The proposed upgrade path is the Identity Toolkit `accounts:update` REST call (ID token + email + password), which should keep the uid. **Unproven** (probe 8.5, second in the probe order); listed in [09-open-decisions.md](09-open-decisions.md#still-unproven).
- Anonymous data does not survive clearing local storage or switching devices [V-8]; the UI says so before an anonymous player invests in a character.
- Enforcement: the session refuses host/GM/content commands from anonymous agents, and rules in RTDB and Firestore refuse the corresponding writes using `auth.token.firebase.sign_in_provider` [V-9] (rules behaviour on real data unproven, probe 8.6).
- **One alias per anonymous account** is enforced in three places:
  1. **Backend.** The anonymous one-alias rule **moves to Firestore** (P10c): Proposed mechanism: an anonymous account's alias is a single fixed-key document, creatable only when it does not already exist, so a second alias is impossible. Full accounts use generated ids. Held: the exact document path and rule wait on the Firestore collection draft (rule behaviour unproven until the Emulator Suite tests).
  2. **App.** The account repository hides "create alias" for anonymous agents once that alias exists and offers the upgrade instead.
  3. **Session (local and LAN play without the backend).** A guest agent identity carries `kind: anonymous`; `OperationHost` refuses a `hello` that presents a second alias for the same anonymous agent id.

## Roles

Admin, moderator and payment tier are **custom claims** on the Auth token, set by the roles Cloud Function with `firebase_admin_sdk` (which supports `setCustomUserClaims`) [V-24]. RTDB and Firestore rules read them from `auth.token` [V-9]. A client sees new claims only after refreshing its ID token [U]; `getIdToken(true)` returned the same token in the probe, so claim pickup is **unproven** (probe 8.4, fourth in the probe order). The Firestore probe did not cover claim-based rules [V-32].

## Badges (Fixed: P9, conditional on probe 8.3)

Ruled by R 2026-10-20 (P9). A badge is a printable/scannable code on a physical agent badge that signs an agent in.

- **Sign-in path:** scanning sends the badge credential to the **badge-login HTTPS Dart function**, which verifies it and returns a custom token minted with `firebase_admin_sdk` `createCustomToken` [V-24]; the app signs in with `signInWithCustomToken`. Firebase rules see `sign_in_provider == "custom"` [V-9]. This ruling is **conditional on probe 8.3** (a real custom token on Windows and Linux).
- **Symbology:** PDF417, not QR.
- **Payload:** only the badge id and a 256-bit secret (about 70 ASCII characters). The secret is stored **hashed**; the badge is revocable and never carries a password.
- **Evidence so far:** a malformed custom token is rejected with `invalid-custom-token` on Windows [V-21]. A real token minted in a deployed function (`createCustomToken`, no key file) signed in via `firebase_dart` on native Linux once the runtime service account held Service Account Token Creator [V-33]. The Windows sign-in with a real token and the badge flow end to end are still **unproven** (probe 8.3, third in the probe order).
- **Deploy checklist:** grant **Service Account Token Creator** (`roles/iam.serviceAccountTokenCreator`) to the function's runtime service account on itself; without it `createCustomToken` fails with `iam.serviceAccounts.signBlob` denied [V-33].
- **Packages not approved yet:** printing (candidate `barcode`), phone scanning (`mobile_scanner`), desktop scanning (`flutter_zxing`, Windows/Linux beta, or USB 2D keyboard-wedge scanners). Each goes to R when badges are scheduled.
- Badges are optional, per agent, listed and revocable from account settings.
- Offline: a badge cannot create a new sign-in without the backend. An agent already signed in on that device keeps working from the local cache.

## Offline accounts (Fixed requirement)

A signed-in account works offline from a local cache. The app keeps its own local record (profile, aliases, campaigns, packs by content hash, operation logs) in the local store (sembast, 09-3; see [04-session.md](04-session.md)).

`firebase_dart` persists query results, not pending writes, per the investigation [V-27][U]. The session therefore owns an **outbox**: requests made offline are stored locally and replayed as ordinary requests on reconnect; the GM stays canonical, so replay is safe (dedupe by request id, [03-protocol.md](03-protocol.md#ordering-and-delivery)). A write queued with `goOffline` was delivered on `goOnline` in the probe [V-21]; whether a queued SDK write survives an **app restart** is **unproven** (probe 8.1, fifth in the probe order), which is why the design relies on its own outbox.

### Auth token storage (Fixed: B5)

Ruled by R 2026-10-20 (B5). By default `firebase_dart` 1.6.2 stores the refresh token and email in plaintext in the Hive box `firebase_auth`, and `FirebaseDart.setup` has no storage option [V-34]. The design:

- After `FirebaseDart.setup` and **before any `FirebaseAuth` use**, `backend` opens the Hive box `firebase_auth` with `HiveAesCipher(key)`. That encrypts the box [V-34].
- The key lives in the OS secure store via `flutter_secure_storage` 11.2.0 (Linux libsecret observed [V-34]; the Windows backend is not stated on its pub.dev page [U]).
- **Guard 1, key access and migration.** Reading or creating the key never fails silently: a wrong or missing key makes Hive truncate the box and sign the user out [V-34], so a key failure is surfaced, not swallowed. A plaintext-to-encrypted migration step handles boxes written before encryption.
- **Guard 2, locked keyring.** On Linux a locked keyring with no prompter blocks the libsecret call forever and freezes the event loop [V-34], so key access runs under a timeout guard and reports instead of hanging. A missing Secret Service gives a clean error [V-34].
- **Dependency:** `hive` 2.2.3 is a direct dependency of `backend`, **pinned exactly**. It must be the same `hive` package `firebase_dart` uses (`hive` ^2.0.0, not `hive_ce`) [V-35].
- **Known accepted risk:** `firebase_dart` depends on `hive`, which has had no release since 2.2.3 (2022-06-30) [V-35], and on `firebaseapis` 0.2.0, whose repository was archived on 2026-03-24 (per the backend investigation, project library `architecture/firebase-desktop-deep-dive.md`).
- Not tested: KWallet (no Secret Service bridge); other platforms.

## Realtime Database model (live play)

**Held: waits on probe 8.6** (P10c). The RTDB live-play tree and its rules are not final until the RTDB rules prototype runs. Under FS1, RTDB keeps **live play only**; the tree below is the existing draft; entries marked → Firestore move there (paths to be drafted). Treat every line as Proposed.

```
/users/$uid                              → Firestore (FS1): profile, kind, settings
/users/$uid/alias                        → Firestore (FS1): anonymous accounts' single alias
/users/$uid/aliases/$aliasId             → Firestore (FS1): full accounts' aliases
/users/$uid/badges/$badgeId              → Firestore draft: hashed badge ref, created, revoked
/inbox/$uid/$push                        in-app notifications (push substitute on Windows/Linux; P14)
/campaigns/$campaignId                   → Firestore (FS1): gm uid, name, members, packRefs, settings
/campaigns/$campaignId/transfers/$id     → Firestore (concern 4): alias transfer requests
/operations/$op/meta                     campaignId, gm uid, engine version, packRef, status (active | archived), locked, lastSeq
/operations/$op/members/$uid             written by the GM client after a join request
/operations/$op/requests/$uid/$push      players write only under their own uid
/operations/$op/events/$audience/$push   event batches per audience; GM uid only; append-only
/operations/$op/textlog/$audience/$push  narrated text per audience; GM uid only; append-only
/operations/$op/head                     head snapshot (state at last seq); GM uid only
/operations/$op/phone/$push              phone messages; members write with from == auth.uid; read by GM and sender
/operations/$op/signaling/$peer          WebRTC offer/answer/candidates (P2P mode only)
/packs/$packId/$version                  → Firestore (FS1): pack index entry (content hash, Storage path)
/archive/pending/$itemId                 → Firestore (FS1): library submissions
/archive/public/$itemId                  → Firestore (FS1): verified library items
/news/$postId                            → Firestore (FS1): information dissemination
```

What the FS1 ruling changes in that draft (Fixed in direction, paths Held):
- **Stays in RTDB:** active operation `events`, `textlog` while active, `requests`, `members`, `phone`, `signaling`, presence, `head` while active, and the inbox. The inbox is at `/inbox/$uid` (P14), so desktop listeners get live updates.
- **Moves to Firestore:** `/campaigns` (including transfer requests, per concern 4), profiles, aliases, `/packs` index, `/archive/pending`, `/archive/public`, `/news`, and the archived form of every operation.
- Badge records stay with the account data; where they live is decided in the Firestore draft.

Notes on the live tree:

- **Per-audience branches.** `$audience` is `gm`, `public` or `alias:<id>`. RTDB rules grant reads per path, so the GM reads everything, members read `public`, and an alias owner reads only their own branch. GM-only events and text are never stored where a player can read them. This replaces the earlier Firestore per-audience documents (P12).
- **Head snapshot (P12).** Non-web hosts write the head snapshot to the local store with every batch. It is **mirrored to RTDB on the GM-configurable per-operation interval** ([04-session.md](04-session.md)); events and text go to RTDB every batch.
- **Joins (B3, Fixed).** Join requests are answered by the GM client, which writes `members/$uid` under RTDB rules.
- **Archiving.** The `archiveOperation` function (below) copies the frozen log to Firestore; the GM client then sets `meta/locked`, which rules check. Archived logs are chunked into a Firestore subcollection (FS5). Migrated operations get a new id; the genesis event lists the archives ([05-migrator.md](05-migrator.md#archived-logs-fixed-ruled-by-r)).
- **Scale.** RTDB's docs give about 200k simultaneous connections per database and about 1,000 writes per second per database, with multiple databases available on the Blaze plan [V-25]. Index nodes are denormalised so clients never scan large branches.
- **Rules are unproven** until the rules prototype runs (probe 8.6, first in the probe order).

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
| `archiveOperation` | Called by the GM client with the frozen event log, text log and final head; validates the shape and writes the archive to Firestore (chunked, FS5) via `firebase_admin_sdk` (FS3). The GM client then sets `meta/locked` |

### Calling functions from desktop (Fixed: B6)

Desktop calls a callable by its full URL with `POST`, `Authorization: Bearer <Firebase ID token>` and the body envelope `{"data": ...}`; success is `200 {"response": ...}`. Probed on Windows and Linux: 200 with the handler seeing the caller's `request.auth.uid`; a bad token gets 401 from the framework; with no token the framework did not reject (the handler saw no auth, so each handler must check `request.auth` itself) [V-33].

### Function credentials and RTDB access (Fixed: FS3)

Ruled by R 2026-10-20 (FS3), with the probe evidence in [V-33]. `firebase_admin_sdk` 0.5.6 and `firebase_functions` 0.8.0 are approved. `firebase_admin_sdk` has Auth, Messaging, Storage, App Check, Firestore, Functions and Security Rules libraries but **no** Realtime Database library [V-24]. So:

- **Firestore** writes (such as the archive) go through `firebase_admin_sdk`; a chunk of about 920 KiB was written and read back [V-33].
- **RTDB** reads and writes from a function are the function's **own REST calls** using the runtime's **default credential**: no key files and no scope handling. The probe wrote and read RTDB this way [V-33].
- **Scoping:** requests are admin (bypass rules) unless the call passes `auth_variable_override`, which switches the request to rules evaluation; the parameter is honored on REST [V-33]. Functions use it to stay scoped to rules where that is wanted. Whether an overridden uid is then allowed by a matching rule was not tested.
- **Service accounts:** each function group runs as a **dedicated runtime service account** (least privilege), not the default compute account. The **least IAM role for RTDB is still untested** [V-33]; until it is, the role is an open item for the deploy checklist.
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

Ruled by R 2026-10-20. Credentialed probes can run in the cloud or on R's PC.

| Order | Probe | Status |
|---|---|---|
| done | FS2 Firestore REST write and `runQuery` under rules, Windows and Linux | Done [V-32] |
| done | 8.1b functions read/write RTDB over REST, callable by URL (FS3, B6) | Done [V-33] |
| done | B5 token storage and secure store | Done [V-34][V-35] |
| 1 | 8.6 RTDB rules prototype | Next; unblocks P10c |
| 2 | 8.5 anonymous upgrade | Open |
| 3 | 8.3 real custom token on Windows and Linux (Linux sign-in already succeeded [V-33]) | Open |
| 4 | 8.4 custom-claim pickup | Open |
| 5 | 8.1 queued write across app restart | Open |
| later | 8.1c, 8.7, Storage via `firebase_dart`, long sessions, other platforms | Not scheduled |
