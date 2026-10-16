# 06. Accounts and backend

## Backend role (Fixed)

Accounts, session persistence and relay, rules pack distribution, information dissemination (news, D's announcements), payments. The backend **never runs game rules**: no backend code imports the engine (see dependency rules in [00-overview.md](00-overview.md#dependency-rules)).

## Stack (Fixed: adopted by R)

R adopted the stack from the backend-split investigation (project library: `architecture/backend-split.md` and its review). Firebase-first stays the preference, with the Firebase console as the admin tool for D and content auditors.

| Layer | Choice | Notes |
|---|---|---|
| Client SDK | `firebase_dart` 1.6.2 (Auth, Realtime Database, Storage) as the single adapter wherever it runs. Auth and RTDB probed [V-21]; Storage **not yet probed** | FlutterFire only where it is needed (likely the web build) |
| Live game data | **Firebase Realtime Database (RTDB)**: relay, event log, session state | Replaces Firestore for v1. R accepted RTDB instead of Firestore |
| Files | Cloud Storage for Firebase (rules pack files) | Uploads by D through the console. Client Storage access through `firebase_dart` is unproven (open item B2) |
| Server code | **HTTPS-only Dart Cloud Functions** (experimental; R accepted that) [V-23] | Badge tokens, role claims, payments, push (Proposed list below) |
| Hosting | Firebase Hosting (web build) | — |
| Cloud Run | Only for long-lived connections; none planned | The earlier desktop Cloud Run gateway is dropped |

Platform targets: **Linux is required in v1** (R). `firebase_dart` was probed on Windows and on Linux (WSL2 Ubuntu) with identical results [V-21]. macOS, iOS, Android and web were not probed.

### Backend port and adapters (Proposed)

`session` talks to the backend only through a **backend port** with four capabilities: auth, tree store (RTDB-shaped reads/writes with rules), event stream (live listeners), blob fetch (Storage). Implementations live in the proposed `backend` package:

| Adapter | Used on | Built on |
|---|---|---|
| `FirebaseDartAdapter` | Windows and Linux (probed); macOS and mobile expected but unproven | `firebase_dart` |
| `FlutterFireAdapter` | where `firebase_dart` cannot run (likely web) | FlutterFire plugins |
| `LanAdapter` | LAN/in-person play with no backend | session transports |

Swapping adapters never touches session or engine. FlutterFire `cloud_firestore` 7.0.0 failed to link on Windows in the probe [V-22] (an observation, not R's stated reason for dropping Firestore).

### Firestore

Dropped from the v1 client. `firebase_dart` has no Firestore client of its own [U]; a Firestore REST read with an ID token succeeded in the probe [V-21], and that would need a Firestore database alongside RTDB. Whether to keep that escape hatch is open for R ([09-open-decisions.md](09-open-decisions.md#open-items-for-r)).

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

Rules:

- An alias is locked to one campaign (Fixed). Moving it creates a transfer request; the **destination** campaign's GM approves. (Whether the source GM must also release it is not specified by R; noted in [09-open-decisions.md](09-open-decisions.md#concerns-raised).)
- **Anonymous accounts** (Fixed): can join any session, have exactly one alias, cannot GM, host or create content. Anonymous sign-in works in `firebase_dart` on Windows and Linux [V-21].
- **Upgrading an anonymous account:** `firebase_dart` has no `linkWithCredential` [U], and signing in with email after anonymous produced a **new** uid in the probe [V-21]. The proposed upgrade path is the Identity Toolkit `accounts:update` REST call (ID token + email + password), which should keep the uid. **Unproven** (probe 8.5); open in [09-open-decisions.md](09-open-decisions.md#open-items-for-r).
- Anonymous data does not survive clearing local storage or switching devices [V-8]; the UI says so before an anonymous player invests in a character.
- Enforcement: the session refuses host/GM/content commands from anonymous agents, and RTDB rules refuse the corresponding writes using `auth.token.firebase.sign_in_provider` [V-9] (rules behaviour on real data unproven, probe 8.6).
- **One alias per anonymous account** is enforced in three places:
  1. **Backend.** An anonymous account's alias lives at the fixed key `/users/$uid/alias`; the rule allows creating it only when `!data.exists()`, so a second alias is impossible (Proposed; unproven until the rules prototype, probe 8.6). Full accounts use generated keys.
  2. **App.** The account repository hides "create alias" for anonymous agents once that alias exists and offers the upgrade instead.
  3. **Session (local and LAN play without the backend).** A guest agent identity carries `kind: anonymous`; `OperationHost` refuses a `hello` that presents a second alias for the same anonymous agent id.

## Roles

Admin, moderator and payment tier are **custom claims** on the Auth token, set by a Cloud Function with `firebase_admin_sdk` (which supports `setCustomUserClaims`) [V-24]. RTDB rules read them from `auth.token` [V-9]. A client sees new claims only after refreshing its ID token [U]; `getIdToken(true)` returned the same token in the probe, so claim pickup is **unproven** (probe 8.4).

## Badges (Fixed concept, Proposed mechanism)

A badge is a printable/scannable code (for example a QR on a physical agent badge) that signs an agent in.

- The badge encodes an opaque, revocable badge token, never a password.
- Scanning sends the token to the **badge-login Cloud Function**, which verifies it and returns a custom token minted with `firebase_admin_sdk` `createCustomToken` [V-24]; the app signs in with `signInWithCustomToken`. Firebase rules see `sign_in_provider == "custom"` [V-9].
- A malformed custom token is rejected with `invalid-custom-token` on Windows [V-21]; signing in with a **real** custom token on Windows/Linux is **unproven** (probe 8.3).
- Badges are optional, per agent, listed and revocable from account settings.
- Offline: a badge cannot create a new sign-in without the backend. An agent already signed in on that device keeps working from the local cache.

## Offline accounts (Fixed requirement)

A signed-in account works offline from a local cache. The app keeps its own local record (profile, aliases, campaigns, packs by content hash, operation logs) in the local store chosen in [09-open-decisions.md](09-open-decisions.md#3-persistence).

`firebase_dart` persists query results, not pending writes, per the investigation [V-27][U]. The session therefore owns an **outbox**: requests made offline are stored locally and replayed as ordinary requests on reconnect; the GM stays canonical, so replay is safe (dedupe by request id, [03-protocol.md](03-protocol.md#ordering-and-delivery)). A write queued with `goOffline` was delivered on `goOnline` in the probe [V-21]; whether a queued SDK write survives an **app restart** is **unproven** (probe 8.1), which is why the design relies on its own outbox.

Auth tokens are stored at the path given to `firebase_dart` setup, in plaintext unless the app encrypts them [U]. Open item in [09-open-decisions.md](09-open-decisions.md#open-items-for-r).

## Realtime Database model (Proposed)

```
/users/$uid                              profile, kind, settings          owner read/write
/users/$uid/alias                        anonymous accounts' single alias (fixed key)
/users/$uid/aliases/$aliasId             full accounts' aliases
/users/$uid/badges/$badgeId              hashed badge ref, created, revoked
/users/$uid/inbox/$push                  in-app notifications (push substitute on Windows/Linux)
/campaigns/$campaignId                   gm uid, name, members, packRefs, settings
/campaigns/$campaignId/transfers/$id     alias transfer requests
/operations/$op/meta                     campaignId, gm uid, engine version, packRef, status (active | archived), locked, lastSeq
/operations/$op/members/$uid             written by the GM client after a join request
/operations/$op/requests/$uid/$push      players write only under their own uid
/operations/$op/events/$audience/$push   event batches per audience; GM uid only; append-only
/operations/$op/textlog/$audience/$push  narrated text per audience; GM uid only; append-only
/operations/$op/head                     head snapshot (state at last seq); GM uid only
/operations/$op/phone/$push              phone messages; members write with from == auth.uid; read by GM and sender
/operations/$op/signaling/$peer          WebRTC offer/answer/candidates (P2P mode only)
/packs/$packId/$version                  pack index entry (content hash, Storage path)
/archive/pending/$itemId                 library submissions
/archive/public/$itemId                  verified library items; public read; .validate on shape
/news/$postId                            information dissemination
```

- **Per-audience branches.** `$audience` is `gm`, `public` or `alias:<id>`. RTDB rules grant reads per path, so the GM reads everything, members read `public`, and an alias owner reads only their own branch. GM-only events and text are never stored where a player can read them. This replaces the earlier Firestore per-audience documents (P12).
- **Append-only and archives.** Event and text batches are write-once (`!data.exists()`); an archived operation sets `meta/locked` (and `status: archived`), which rules check, freezing its log. Its frozen events and text log stay where they were, under its own `/operations/$op/events` and `/operations/$op/textlog`. Migrated operations get a new id; the genesis event lists the archives ([05-migrator.md](05-migrator.md#archived-logs-fixed-ruled-by-r)).
- **Library.** Submissions land in `/archive/pending`; a reviewer holding a moderator custom claim copies an item to `/archive/public` from the client, under rules, which also record who verified it and when. This is the government-style public archive of verified items (Fixed). Who holds that claim is still open (concern 5 in [09-open-decisions.md](09-open-decisions.md#concerns-raised)).
- **Packs.** The pack index (id, version, content hash, Storage path) is in RTDB; pack files are in Cloud Storage; D uploads through the console. Clients validate packs with the engine on load ([02-rules-packs.md](02-rules-packs.md#loading-and-validation)).
- **Scale.** RTDB documents about 200k simultaneous connections and about 1,000 writes per second per database, with multiple databases available on the Blaze plan [V-25]. Index nodes are denormalised so clients never scan large branches.
- **Rules are unproven** until the rules prototype runs (probe 8.6). Every rule in this section is Proposed.

## Relay

In network-hosted mode the backend relays and persists (Fixed). With this stack the relay **is RTDB**: the GM writes event batches under `/operations/$op/events`, participants listen; players write requests under their own uid, the GM listens. A listener on a second client instance received writes in the probe, with reads and writes around 50 ms [V-21]. No custom relay server.

## Cloud Functions (Dart, HTTPS-only; function list Proposed)

Dart Cloud Functions are experimental and may change without notice. They require enabling the `dartfunctions` experiment in the Firebase CLI, the Blaze plan, Dart 3.9+ and a recent CLI. In production only HTTP (`onRequest`) and callable (`onCall`, including `onCallWithData`) triggers can be deployed; other triggers run only in the emulator, so there are no deployed database, storage, scheduled, Pub/Sub, Auth-blocking or task-queue triggers. Dart callables cannot be called by name from client SDKs, only by their full URL, and the Firebase console does not display Dart functions (they appear in the Cloud console) [V-23].

| Function | Does |
|---|---|
| Badge login | Verify badge token, `createCustomToken` |
| Roles | Set admin / moderator / tier custom claims |
| Payment webhook | Receive the payment provider's webhook (`onRequest`), set the tier claim |
| Store receipts | Validate app-store receipts [U] |
| Pack publishing helper | Assist publishing a pack version (index + Storage) |
| Mobile/web push | Send via `firebase_admin_sdk` Messaging [V-24] |

- Desktop calls functions by URL over HTTPS POST with a Bearer ID token and the callable envelope [U] (open item B6).
- Anything that would need database, auth or scheduled triggers is designed out, done as a manual script, or done in a Node function (needs R's approval).

### Firebase Admin and RTDB

`firebase_admin_sdk` 0.5.6 (approved by R, as is `firebase_functions` 0.8.0) provides Auth (`createCustomToken`, `setCustomUserClaims`), Messaging, Storage, App Check, Firestore, Functions and Security Rules libraries, but **no** Realtime Database library [V-24]. So functions cannot write RTDB through it. Proposed: its Storage admin library could serve the pack publishing helper. Default: such writes are made by clients under rules (the GM client writes `members`, moderators move library items). Alternatives, both open: RTDB REST writes with a service-account OAuth token (probe 8.1b), or a Node function (R).

## Push notifications

`firebase_messaging` 17.0.0 describes itself as delivering messages on Android and iOS, and the investigation found no Windows or Linux support [V-26][U]. On those platforms notifications are **in-app only**, via `/users/$uid/inbox`. Mobile and web push go through the push function.

## App Check

`firebase_app_check` 0.5.0 lists Windows, but official docs do not [V-26][U]; there is no App Check for Linux or `firebase_dart` [U]. Open item B4.

## Payments

Payments are a backend role (Fixed). The investigation sketched Stripe Checkout through an `onRequest` webhook that sets a tier claim, but payment and store policy was not researched (probe 8.8). No provider is decided. The app reserves an `Entitlements` read model fed by claims. Listed in [09-open-decisions.md](09-open-decisions.md#concerns-raised).

## Environments

Firebase's security checklist recommends separate development, staging and production projects and the Local Emulator Suite [V-19]. Proposed: three Firebase projects; RTDB rules and functions tested in the emulator. Desktop clients need network access to `*.firebaseio.com`, `*.firebasedatabase.app` and `identitytoolkit.googleapis.com` (allowlist used by the probe) [U].
