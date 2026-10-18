# Firebase on Windows and Linux desktop: deep dive

Date: 2026-10-16. Prepared for R. Research is web-based (pub.dev, GitHub, Firebase and Google Cloud docs). The only thing run on a machine is the `firebaseapis` probe on R's PC (section 7). Nothing is committed or pushed.

Labels: **[V]** read directly from a source this session, **[S]** secondhand (a commenter's claim), **[U]** unverified or from background knowledge, to be confirmed before relying on it.

## 1. Summary

1. **Windows**: FlutterFire has official plugins for Core, Auth, Firestore and Storage on Windows. They wrap the Firebase C++ SDK. Firebase's own docs say Windows is "not intended for production use cases, only local development workflows" [V]. They work in practice (R's experience) but have open bugs (section 2.3). Realtime Database, Messaging, Functions, Remote Config and App Check are N/A on Windows in FlutterFire [V].
2. **Linux**: FlutterFire has no support. `firebase_core` and `firebase_auth` do not list Linux [V]. Requests (#17338, #17585) have no maintainer commitment; a commenter says it is not on the roadmap [S]. The old Invertase desktop effort (`flutterfire_desktop`) was archived 2026-10-01 [V].
3. **Pure-Dart client packages that run on both**: `firebase_dart` 1.6.2 (Mar 27 2026) covers Auth, Realtime Database and Storage but **not Firestore** [V]. `firedart` 0.9.8 (Mar 2024) covers Firestore and Auth subsets with serious gaps [V]. Nothing maintained gives full Firestore (listeners, offline cache, queries) on Linux.
4. **Server side**: the official `firebase_admin_sdk` 0.5.6 (Sep 21 2026, publisher firebase.google.com) is solid for a Dart server on Cloud Run: Auth (incl. `createCustomToken`), Firestore, Messaging, Storage, App Check, Security Rules [V]. It has no Firestore realtime listeners documented and no Realtime Database support [V].
5. **The gateway is small.** Cloud Run is needed for custom-token minting (badge login), store receipt validation, privileged admin actions, and (if we choose) a Linux fallback. It does not have to carry the realtime event relay.

Recommendation in section 8. The main open question for R is how to treat Linux and whether the realtime relay should sit on Firestore or Realtime Database.

## 2. FlutterFire on Windows

### 2.1 What exists
- Latest bill of materials: BoM 5.0.0 (Oct 15 2026), `firebase_core` 5.0.0, `firebase_auth` 7.0.0, `cloud_firestore` 7.0.0, Windows native SDK 14.0.0 [V: firebase release notes, pub.dev]. All three list Windows and omit Linux on pub.dev [V].
- Windows plugins are bridges to the Firebase C++ SDK through Pigeon-generated C++ messages [V: issue #18659].
- Support table (flutterfire README) [V]: Core, Auth, Firestore, Storage = Windows `(*)`; Analytics, App Check, Functions, Messaging, Crashlytics, Installations, Realtime Database, Remote Config, Performance = N/A. Footnote `(*)`: "for development only. Production on Windows is not supported."
- The C++ SDK itself describes desktop (Windows, macOS, Linux) as beta, "intended only for workflows during the development of your game, not for publicly shipping code" [V: firebase.google.com/docs/cpp/setup]. It supports App Check, Auth, Firestore, Functions, Storage, Realtime Database and Remote Config on desktop. Messaging is not supported on desktop [V]. The C++ SDK's desktop Realtime Database uses REST and needs indexes for `orderByChild` queries [V].
- Custom-token sign-in exists in the C++ Auth API (`SignInWithCustomToken`) [V]. Whether the Flutter Windows plugin exposes every Auth method (anonymous sign-in, custom token) was not confirmed from docs [U]. This is the first thing to test.

### 2.2 Production stance
Both the FlutterFire table and the C++ SDK say not for production on desktop. That is an unsupported-by-vendor risk, not a measured failure. R reports it works; the issues below show what can go wrong.

### 2.3 Known Windows issues found
| Issue | What | Status |
|---|---|---|
| [#18659](https://github.com/firebase/flutterfire/issues/18659) | `persistenceEnabled: false` ignored on Windows (disk cache always on). Settings fixed at first Firestore instance creation. | Confirmed by maintainer, fix pending. Windows SDK 13.12 release notes say it is now honored (BoM 4.20.0, Sep 14 2026) [V], so likely fixed; recheck on 5.0.0 [U]. |
| [#13212](https://github.com/firebase/flutterfire/issues/13212) | After switching users, Firestore keeps the previous user's token ("Missing or insufficient permissions") until app restart. | No confirmed fix in thread. Matters for alias/agent switching. Test before relying on it. |
| [#12987](https://github.com/firebase/flutterfire/issues/12987) | Windows crash fetching a document / cache crashes (title only read). | Not investigated further [U]. |
| C++ SDK #1703 | `sum()` / `avg()` aggregations not implemented in C++; BoM 5.0.0 notes "reporting sum/average aggregations as unimplemented" [V]. | Open feature request. `count()` works. |
| General | Firestore `isNotEqualTo`, `whereNotIn`, `limitToLast`, cursors reportedly fail on desktop except macOS (claim from `firebase_for_all` README, old, 2023) [S]. | Verify against current plugin [U]. |

Given our use (documents, event append, simple queries), the aggregation gap is irrelevant. The token-switch bug and any query gaps matter.

## 3. FlutterFire on Linux

- No official support. No Linux column in the README table [V]; `firebase_core` / `firebase_auth` list no Linux on pub.dev [V].
- [#17338](https://github.com/firebase/flutterfire/issues/17338) (Auth Linux) has no maintainer statement. A commenter says the PR to add Linux was dropped and it is not on the roadmap [S]. [#17585](https://github.com/firebase/flutterfire/issues/17585) (Remote Config) was closed as a duplicate [V]. [#2028](https://github.com/firebase/flutterfire/issues/2028): a maintainer (stuartmorgan) flagged the C++ SDK's desktop support as beta for game-dev workflows; contributors favored pure-Dart implementations [V].
- Community workarounds: forks adding Linux, or a Flutter web build [S].
- The Invertase `flutterfire_desktop` repo (pure-Dart Auth/Core for Linux and Windows, "early-stage, experimental") was archived Oct 1 2026 [V]. `firebase_auth_desktop` 1.0.2 is from Aug 2022 and not marked discontinued, but is effectively stale [V]. Do not build on it.
- The C++ SDK does list Linux builds (Ubuntu, GCC 4.8 / 7.2, Clang 5) as beta [V]. Wrapping it in our own Flutter Linux plugin is possible in principle but is a large maintenance item [U]. Not recommended.

## 4. Maintained pure-Dart packages that run on Windows (and Linux)

| Package | Version / date | Covers | Platforms | Gaps / health |
|---|---|---|---|---|
| [`firebase_dart`](https://pub.dev/packages/firebase_dart) (appsup-dart) | 1.6.2, Mar 27 2026; 2.0.0-dev.2 prerelease | Auth, Realtime Database, Cloud Storage [V]. **No Firestore** [V]. | All Flutter targets incl. Linux, Windows | Unsupported Auth: `signInWithPopup/Redirect`, `linkWithCredential`, phone linking, `setPersistence`, `verifyBeforeUpdateEmail` [V]. RTDB `setPersistenceEnabled` caches query results but not writes [V]. Query optimizations may be refused by rules that official clients allow [V]. Repo: 16 open issues, 1 open PR, 1,116 commits [V]. Actively fixed (1.6.1 fixed a listener-revoke crash) [V]. Best candidate. |
| [`firedart`](https://pub.dev/packages/firedart) (cachapa) | 0.9.8, Mar 2024 | Auth (email/password, anonymous, custom token) and Firestore subset via gRPC [V] | Android, iOS, Linux, macOS, Windows | No `limit`/`sort` queries, no local cache, no write retry, closed streams not recovered [V]. 43 open issues, 5 PRs [V]. Stale. Not suitable for the event relay. |
| [`firebase_for_all`](https://pub.dev/packages/firebase_for_all) | 0.1.1, Feb 2023 | Wrapper: FlutterFire elsewhere, firedart on Windows [V] | | Stale; inherits firedart limits. Skip. |
| [`firebaseapis`](https://pub.dev/packages/firebaseapis) (Invertase) | 0.2.0, Aug 2023; repo archived Mar 24 2026 [V] | Discovery-generated REST clients: Firestore v1, Identity Toolkit v1/v2/v3, FCM v1, RTDB management, Storage, Hosting, Rules, App Check, Functions [V] | Pure Dart; all targets | No realtime listeners, no offline cache, no on-device sign-in. No securetoken API [V]. Archived. Vendor/pin if used at all. See section 7. |

What the REST/gRPC surfaces can and cannot do:
- **Firestore REST**: CRUD, queries, batch/commit, transactions. The docs page fetched does not discuss streaming; Firestore realtime listen is the gRPC `Listen` / WebChannel protocol, which REST does not expose [U: background knowledge]. `firedart` implements gRPC listen but is stale.
- **Realtime Database REST**: supports streaming via `Accept: text/event-stream` (SSE), with `put`, `patch`, `keep-alive`, `cancel`, `auth_revoked` events, 307 redirects to follow, and `auth` token param [V: Firebase blog 2014 and docs]. Any Dart `http` client can consume it. `firebase_dart` already does this for us at higher level [V].
- **Identity Toolkit REST**: email/password and anonymous sign-up/in, token refresh via Secure Token API, custom-token exchange (`signInWithCustomToken`) [U: background knowledge, well-documented; verify in probe].

## 5. Dart server (Cloud Run) capabilities

- `firebase_admin_sdk` 0.5.6, official, Dart SDK 3.9+ [V]. Supported: App, App Check, Auth, Firestore (via `google_cloud_firestore` 0.5.3), Functions, Messaging, Security Rules, Storage (via `google_cloud_storage`). Not supported: Realtime Database, Remote Config, Data Connect, Installations, Eventarc [V]. Auth: `createCustomToken` with developer claims [V]; `listUsers` max 1000/page [V]. Firestore: reads/writes/queries/batch/transactions/BulkWriter, no listeners documented [V]. Limitation: OAuth refresh tokens unsupported for Firestore [V].
- `dart_firebase_admin` 0.4.1 is discontinued, replaced by the above [V].
- **Dart Cloud Functions are still experimental (resolved 2026-10-16).** The earlier project note stands. The conflict was dart.dev's wording: [dart.dev/server/google-cloud](https://dart.dev/server/google-cloud) says Dart is supported and never uses the word "experimental" [V], but Firebase's own docs do [V]:
  - [Get started with the experimental Dart SDK](https://firebase.google.com/docs/functions/start-dart): "This feature is experimental and may change without notice." Needs Dart SDK 3.9+, Firebase CLI 15.15.0+, opt-in `firebase experiments:enable dartfunctions`, and the **Blaze plan to deploy** (emulation works on any plan). Only `onRequest` and `onCall` can be deployed. The CLI compiles locally and uploads a binary to Cloud Run functions (no Cloud Build). `onCall` can't be invoked by name from client SDKs; use `httpsCallableFromURL` with the Cloud Run URL. Functions don't show in the Firebase console yet, only the Cloud Run page in Google Cloud console.
  - [`firebase_functions` 0.8.0](https://pub.dev/packages/firebase_functions) (Sep 15 2026, firebase.google.com): "Only HTTPS triggers are currently supported in production."
  - [Trigger support levels](https://github.com/firebase/firebase-functions-dart/blob/main/doc/triggers.md): production = HTTPS (`onRequest`, `onCall`, `onCallWithData`); emulator only = Firestore, Realtime Database, Cloud Storage; experimental/not in production = Pub/Sub, Scheduler, Alerts, Eventarc, Identity Platform blocking triggers, Remote Config, Test Lab, Task Queues.
  - Consequence: no deployable Firestore/Auth/scheduled triggers in Dart. Use plain Cloud Run (HTTP) for the gateway. Event-driven work (e.g. reacting to Firestore writes) would need Node/Python functions or Cloud Run with Pub/Sub/Eventarc.
  - Google Developer Knowledge API was not available in this session; the Firebase docs pages above are the primary source.
- Cloud Run + Dart: official Docker image [V]. Cloud Run WebSockets work with no extra config; request timeout max 60 min (default 5); up to 1,000 concurrent connections per container; session affinity is best-effort; an instance with any open WebSocket is billed as active; cross-instance sync needs an external store such as Redis Pub/Sub or Firestore real-time updates [V].

Meaning for "reliable regardless of active users": stateless Cloud Run endpoints (token minting, receipt verification, claims, pack signing) scale horizontally and cost nothing idle. A Cloud Run websocket relay is the part that gets awkward (billing while connected, 60-minute reconnects, cross-instance fan-out). Keep the relay on the Firebase side.

## 6. Mapping BARD backend needs

| Need | Mobile / web / macOS | Windows | Linux |
|---|---|---|---|
| Auth, full accounts and anonymous | FlutterFire Auth | FlutterFire Auth (dev-only caveat), or `firebase_dart` Auth | `firebase_dart` Auth (anonymous, email/password, custom token via REST [U]) |
| Badge login (custom token) | Server mints via admin SDK; client `signInWithCustomToken` | same (C++ supports it [V]; plugin exposure [U]) | `firebase_dart` custom-token sign-in [U] |
| Account data, rules-pack metadata (D's content, console-editable) | Firestore | Firestore via FlutterFire | **gap**: no maintained client. Options: read via gateway, or Storage / RTDB instead |
| Operation state and event log persistence | Firestore | Firestore via FlutterFire | RTDB via `firebase_dart`, or gateway |
| Realtime relay GM <-> players | Firestore listeners or RTDB | Firestore listeners (C++ SDK listen works [U]) | RTDB stream via `firebase_dart` (pure Dart, SSE) |
| Offline cache | Firestore built-in | Firestore C++ persistence (see #18659); we also keep a local sembast cache | our own sembast cache (needed anyway) |
| Pack distribution | Storage / Hosting + Firestore index | Storage via FlutterFire | Storage via `firebase_dart` |
| Notifications | FCM | **not available**; in-app via listener doc | same |
| Payments (badges, books, merch, tiers) | Store receipt validation on Cloud Run, or a web checkout | web checkout / Cloud Run | same |
| Web hosting | Firebase Hosting | n/a | n/a |
| Privileged actions (claims, tier change, moderation) | Cloud Run, `firebase_admin_sdk` | same | same |

Payments note: receipt validation (Google Play, App Store Server API) and any card checkout need a server and are not Firebase client features. I did not deeply research payment packages this pass; treat the payment row as design intent, not verified [U].

## 7. The `firebaseapis` probe (R's PC)
Run by thread "Verify firebaseapis for desktop", results from that thread (not repeated work):
- Steps 1 and 2 pass: `firebaseapis` 0.2.0 resolves on Dart 3.13.2, `dart analyze` clean, Windows `.exe` builds [V from that thread's report].
- Step 3 (Firestore REST read with a Firebase Auth ID token) is **blocked on a test project and account** from R: project ID, web API key, test email/password, readable document path [V from that thread]. The probe session must not search for credentials and does not.
- If R wants the Windows story tested rather than just the REST client, the same test project can be used for a second probe: FlutterFire Auth + Firestore listener on Windows, with a user switch (to reproduce #13212) and `firebase_dart` Auth + RTDB stream on Windows and Linux (Linux needs a Linux machine or WSL2 with Flutter Linux desktop [U]).

## 8. Recommendation and open decisions

Design rule that keeps all options open: the `session` package talks to a small **backend port** (auth, document store, event stream, blob fetch) with swappable adapters. Packages and platform choices stay out of `engine`, `protocol`, `session`.

Suggested default (needs R's decision):
1. **All platforms except Linux**: FlutterFire (Auth, Firestore, Storage). Windows is accepted as "works, vendor-unsupported", gated by a probe for #13212 (user switch) and custom-token sign-in.
2. **Linux**: do not block the architecture on it. Choose one:
   a. Linux relies on `firebase_dart` (Auth + Realtime Database + Storage), which means the realtime relay and event log must be implementable on RTDB, not only Firestore.
   b. Linux is out of v1 and users run the web build.
   c. Linux talks to a thin Cloud Run gateway (REST) that fronts Firestore for it.
   My lean is (a) only if RTDB is acceptable as the relay for **all** platforms (one data path, console-editable, 200,000 simultaneous connections per database and ~1,000 writes/s soft limit [V]); otherwise (b) for v1.
3. **Cloud Run gateway scope (minimal)**: custom-token minting for badges, receipt verification, claims / tier changes, moderation, optional Linux REST shim. Stateless, `firebase_admin_sdk`. No realtime relay.
4. **Do not use** on the client: `firedart`, `firebase_for_all`, `firebase_auth_desktop`, `flutterfire_desktop`, `firebaseapis` (archived; server-only at most, and `firebase_admin_sdk` replaces its main use).

Decisions for R:
- D1. Is Linux in scope for v1, and if so which of 2a / 2b / 2c?
- D2. Firestore vs Realtime Database for the operation event stream (RTDB gives a pure-Dart path to Linux; Firestore gives richer queries and the FlutterFire Windows path).
- D3. Run the second probe (FlutterFire Windows Auth + Firestore + `firebase_dart` RTDB) on a test project? Needs a test Firebase project and account from R.
- D4. (Resolved: Dart Cloud Functions remain experimental, HTTPS triggers only; see section 5.)

## 9. Not verified in this pass
- Windows plugin Auth methods actually exposed (anonymous, custom token); Windows Firestore listener reliability under long sessions.
- Whether #18659 is fixed in `cloud_firestore` 7.0.0 and whether #13212 persists on Windows SDK 14.0.0.
- Firestore concurrent listener and per-document write limits (the quota page excerpt fetched did not contain them; the "real-time queries at scale" page gives no numbers).
- `firebase_dart` behavior on Linux in practice (listed on pub.dev, not run).
- Payment/receipt tooling.
- Last-commit dates for `firedart` and `firebase_dart` (GitHub page capture omitted them).

## Sources
- Firebase for Flutter setup: https://firebase.google.com/docs/flutter/setup
- FlutterFire README: https://github.com/firebase/flutterfire
- FlutterFire release notes: https://firebase.google.com/support/release-notes/flutter
- Issues: https://github.com/firebase/flutterfire/issues/18659 , /13212 , /17338 , /17585 , /2028 ; discussion /8124 ; C++ SDK https://github.com/firebase/firebase-cpp-sdk/issues/1703
- C++ setup (desktop beta): https://firebase.google.com/docs/cpp/setup ; C++ custom auth: https://firebase.google.com/docs/auth/cpp/custom-auth
- pub.dev: firebase_core, firebase_auth, cloud_firestore, firebase_dart (+changelog), firedart, firebase_auth_desktop, firebase_for_all, firebaseapis, firebase_admin_sdk, dart_firebase_admin, google_cloud_firestore
- Repos: https://github.com/appsup-dart/firebase_dart , https://github.com/cachapa/firedart , https://github.com/invertase/flutterfire_desktop , https://github.com/invertase/dart_firebase_apis , https://github.com/firebase/firebase-admin-dart
- RTDB REST streaming: https://firebase.blog/posts/2014/03/announcing-streaming-for-firebase-rest ; RTDB limits: https://firebase.google.com/docs/database/usage/limits
- Cloud Run WebSockets: https://docs.cloud.google.com/run/docs/triggering/websockets ; Dart on Google Cloud: https://dart.dev/server/google-cloud
