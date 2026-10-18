# Backend split: Dart server, Firebase client, Cloud Functions, per-OS

Date: 2026-10-16. Prepared for R. Builds on `firebase-desktop-deep-dive.md` (same folder). Rulings applied: Linux is required in v1; Realtime Database (RTDB) is acceptable instead of Firestore; Dart Cloud Functions are acceptable where appropriate; prefer managed Firebase features and the console.

Labels: **[P]** proven by a probe this session, **[V]** read from a source this session, **[S]** secondhand, **[U]** unverified or background knowledge, to confirm before relying on it.

## 1. Summary

1. **Leading candidate: `firebase_dart` 1.6.2 (Auth + RTDB + Storage) as the one client path on Windows and Linux, proven on Windows and native Linux.** It is pure Dart, so Linux needs no native plugin [V]. Auth, Realtime Database, and the Firestore REST read all pass on both Windows and native Linux (WSL2 Ubuntu, Dart 3.13.5) with identical results [P] (read, write, live listener, offline queue; sections 2.1 and 2.3). Rules, scale and long sessions are still unprototyped. New finding: current FlutterFire pub.dev metadata lists Windows for `firebase_database` 13.0.0 and `firebase_app_check` 0.5.0 [V], so the FlutterFire README support table used in the deep dive is stale. FlutterFire still has no Linux. Native Windows RTDB through FlutterFire is a second option to probe.
2. **FlutterFire on Windows is a weaker base than the earlier deep dive assumed.** Auth builds and works [P]. `cloud_firestore` 7.0.0 failed to link on R's PC (`LNK2001 _Avx2WmemEnabled`, MSVC 14.44) [P]. The Firestore listener and the user-switch bug (#13212) could not be tested. Cause unverified [U].
3. **Operations run on RTDB** (event relay, event log, session state). One path for all platforms, console-editable by D, rules enforce who may write what. Offline writes are not persisted by `firebase_dart` [V], so `session` keeps its own outbox (sembast), which the architecture already wants.
4. **Server code is a small gateway written as Dart Cloud Functions, which are experimental** ("may change without notice"; opt-in flag, Blaze plan, `onCall` / `onRequest` only, not in the Firebase console) [V]. Its jobs: badge custom tokens, custom claims, payment webhooks, receipt checks, moderation actions, pack publishing. **`firebase_admin_sdk` 0.5.6 does not support Realtime Database admin [V]**, so the gateway cannot use it to write to RTDB. Gateway RTDB writes either go through the RTDB REST API with a service-account OAuth token (unprobed) or are replaced by client writes under rules (section 3). Plain Cloud Run is only needed if something must hold a long connection, and nothing planned does.
5. **Firebase features without any code:** Auth (email, anonymous), RTDB + rules, Storage + rules, Hosting, console editing for D. Notifications on Windows/Linux must be in-app (RTDB inbox); FCM is mobile/web only.
6. **Not available in Dart functions in production:** database, Auth and scheduled triggers [V]. Design so none are needed (client-driven writes plus `onCall` actions), or accept one small Node function set.

## 2. Evidence from probes (test project `web-portfolio-2d5c2`)

Probe machine: R's PC, Windows 10, Dart 3.13.2, Flutter 3.47.2. Credentials were passed as per-command env vars only; nothing was written to files.

### 2.1 `firebase_dart` 1.6.2, pure Dart, Windows [P]
| Step | Result |
|---|---|
| `initializeApp` with a fake appId (`1:000000000000:web:0000000000000000`) | PASS. No registered app needed. |
| Email/password sign-in | PASS |
| `getIdToken()` then `getIdToken(true)` | PASS, but both tokens were identical (length 918). Forced refresh returned the same token. See 8.4. |
| `signOut` | PASS |
| Anonymous sign-in | PASS |
| Sign in as email user while anonymous | PASS (new uid, `isAnonymous=false`) |
| `authStateChanges` | PASS (emitted null, user, null, user, user) |
| `signInWithCustomToken('bad')` | PASS: normal `FirebaseAuthException`, code `invalid-custom-token`. Real token not tested (needs a server). |
| RTDB at `https://web-portfolio-2d5c2.firebaseio.com` (legacy-style host; the `-default-rtdb` host 404s because no instance lives there) | **PASS** (rerun with R's URL, scratch inside `C:\GAMES\BARD`): signed-in read of `games/test` and of the root returned `null` (database empty, reads allowed). Write `probe-scratch/<uid>/ping`: set 1 and 2 acked in about 50 ms; an `onValue` listener on a second instance received `null, 1, 2` and then `null` after delete (first event 4 ms, i.e. local cache). `goOffline`, write 3, `goOnline`: the write stayed pending, then reached the server (REST showed 3). App restart while offline not tested, so durability of queued writes is unknown. |
| Unauthenticated REST GET `<url>/games/test.json` | HTTP 200 `null`. Not a rules denial, so reads are open on the empty node; whether rules require auth on real data is not shown [U]. |
| Firestore REST read `documents/games/test` with the ID token | PASS, HTTP 200, `{"test-value":"Hello from Firebase!"}` |

### 2.2 FlutterFire on Windows desktop [P]
- Versions: `firebase_core` ^5.0.0, `firebase_auth` ^7.0.0, `cloud_firestore` ^7.0.0.
- `cloud_firestore` added: `flutter build windows` fails in debug and release with `LNK2001/LNK2019: unresolved external symbol _Avx2WmemEnabled` in `firebase_firestore.lib`. MSVC toolset 14.44.35207 (VS 2022 Community). Probably a mismatch between the prebuilt C++ library and the installed STL [U].
- `cloud_firestore` removed: release build 15 s. Initialize (fake appId), email sign-in and anonymous sign-in PASS. `signInWithCustomToken('bad')` throws a normal `FirebaseAuthException` (`invalid-custom-token`), so custom-token login is exposed on Windows.
- Not tested: Firestore get, snapshot listener, user switch (#13212).
- Build notes: first build failed because the long Temp path broke MSBuild (FTK1011); moved to a short path. Linker PDB warnings (LNK4099, libcurl). No production-use warning printed.

### 2.3 Linux (native, WSL2 Ubuntu) [P]
Dart SDK 3.13.5 stable linux_x64, `firebase_dart` 1.6.2, `dart run`, RTDB at `https://web-portfolio-2d5c2.firebaseio.com`. Every step passes and matches Windows: email sign-in (487 ms), `getIdToken` and forced refresh (both 918 chars, identical token), signOut, anonymous sign-in, anon-to-email switch, `authStateChanges`, bad custom token rejected with `invalid-custom-token`, RTDB read of `games/test` (null, 277 ms) and root (null), write/listen/delete on a scratch path (writes acked about 52 ms, listener saw null, 1, 2), offline write delivered after `goOnline`, and Firestore REST read with the ID token (200). The same uid is returned on Windows and Linux. Not tested: queued-write survival across an app restart.
- Earlier failures in my cloud container (`auth/internal-error`) were the sandbox proxy (tunnel closed mid-exchange), not the package.
- Allowlist for cloud threads needs both `*.firebaseio.com` and `*.firebasedatabase.app`, plus `identitytoolkit.googleapis.com` working end to end.

## 3. Component split

Legend: **C** = Firebase client (`firebase_dart` / FlutterFire), **R** = Firebase rules only, **F** = Dart Cloud Function, **X** = no backend (local), **N** = Firebase feature, console only.

| Backend need | Who does it | Notes |
|---|---|---|
| Sign-in: email/password, anonymous | C + N | `firebase_dart` on Windows/Linux [P Windows]; FlutterFire on mobile/web. Providers enabled in console. |
| Anonymous to full account (keep uid, alias) | C (REST fallback) | `firebase_dart` does not support `linkWithCredential` [V]. Use Identity Toolkit REST `accounts:update` (setAccountInfo) with the anonymous user's `idToken`, `email` and `password` (the documented "link with email/password" flow) [V: review]. Unprobed; confirm the uid is preserved [U]. |
| Badge login | F + C | Function verifies the badge, mints a custom token with `firebase_admin_sdk` `createCustomToken` [V]; client calls `signInWithCustomToken` (exposed on both stacks [P]). Signing permission on the function's service account needed [U]. Needs an owner for the badge verification data and for service-account key custody (prefer keyless signing with the runtime service account, no key file) [U]. |
| Roles/tier (admin, moderator, tier) | F + R | Custom claims set only by a function [V: set server-side only]. Rules read `auth.token`. Client sees a change after its token refreshes (8.4). |
| Account / alias data | C + R | RTDB `/users/$uid/...`. Rules: owner read/write own. One campaign per alias enforced by data + rules; moving needs GM approval (a request path the GM client resolves). |
| Operation event relay GM <-> players | C + R | RTDB: players write `/operations/$op/requests/$uid/$push`, only GM uid writes `/operations/$op/events/$push`. Listeners are streaming. 200,000 connections and about 1,000 writes/s per database [V]. |
| Operation persistence / history | C + R | Same tree. Event log append-only by rule. Archive-only after majors per the existing spec. |
| Membership / join | R (+ F for claims only) | Because `firebase_admin_sdk` cannot write RTDB [V], default to client writes under rules: a player writes a join request, the GM client (canonical) writes `/operations/$op/members/$uid`. Anonymous limits (no GM/host/create) via rules on `auth.token.firebase.sign_in_provider` [U, verify in rules prototype]. Alternative: the function writes through RTDB REST with a service-account OAuth token (unprobed). |
| One alias per anonymous account | R | Needs a concrete mechanism: store the alias at a fixed key `/users/$uid/alias` (not a push list) for anonymous users, so a second alias is an overwrite the rules can refuse (`!data.exists()`). To prototype [U]. |
| In-game phone messaging to GM | C + R | `/operations/$op/phone/$gmInbox/$push` writable by any member as `from=$uid` (validated), readable by the GM and sender; GM client fans out replies. Same pattern as requests. Prototype [U]. |
| Offline cache of alias and pack data | X | Local sembast store seeded from RTDB reads and Storage pack downloads; versioned by pack hash. Reconnect: GM state is canonical, so clients replay the outbox as requests and the GM client re-broadcasts. `firebase_dart` RTDB caches query results only [V]. |
| Archive-only logs after an engine major | R + C | Frozen log under `/operations/$old/events` set write-once by rule (`!data.exists()` / locked flag); the plain-text rendering stored next to it; new op id for the genesis log. Per-audience read rules apply (P12/P13 move from Firestore rules to RTDB rules; spec change for R). |
| Calling gateway functions from desktop clients | C | `onCall` is invoked by Cloud Run URL, not by name [V]; `firebase_dart` lists no Functions client, so use a plain HTTPS POST with `Authorization: Bearer <ID token>` and the callable JSON envelope (or `onRequest`). Unprobed [U]. |
| Offline cache / outbox | X | `firebase_dart` RTDB persistence stores query results, not writes [V]. `session` keeps a sembast outbox. |
| P2P / LAN hosting | X | Outside Firebase. Separate transport adapter behind the backend port. |
| Rules-pack distribution | N + C | D uploads to Storage and edits an index in RTDB from the console. Clients fetch via `firebase_dart` Storage [V]. Pack signing / hash stored in the index. |
| D publishes default content | N | Console only (RTDB editor + Storage). Validation via `.validate` rules. |
| Public archive moderation | R (+ F claims) | Submissions to `/archive/pending`; users with a moderator/admin claim copy to `/archive/public` from their client under rules (`.validate` checks shape). Public read. A function doing the move would need the RTDB REST route (unprobed). |
| Notifications | C + R, FCM on mobile/web | Windows/Linux: in-app via RTDB `/users/$uid/inbox` listener. FlutterFire Messaging is N/A on Windows [V]; `firebase_dart` has no FCM [V]. Server sends push via `firebase_admin_sdk` Messaging for mobile/web [V]. |
| Payments (badges, books, merch, tiers) | F | Physical goods: web checkout (Stripe Checkout via `onRequest` webhook, or the Invertase "Run Payments with Stripe" extension, which is Node, Firestore-based, console-installed [S]). Account tiers sold inside iOS/Android apps need store IAP and receipt validation in a function [U: store policy, not researched]. Webhook sets the tier claim. |
| Web hosting | N | Firebase Hosting. |
| App Check | partly | FlutterFire changelog: Windows support added (`firebase_app_check_platform_interface` 0.3.0, BoM 4.12.0, 2026-04-13, PR #18140) [V]; `firebase_app_check` 0.5.0 lists Windows [V]. The official App Check page lists only Apple, Android, Web and custom backends [V], and the FlutterFire README table still says N/A, so treat Windows as unconfirmed [U]. Linux: none. `firebase_dart`: not listed [V]. App Check can protect a self-hosted backend such as the gateway [V: review]; Dart verification unverified [U]. Rules remain the real gate. |

## 4. Why RTDB for operations
- Only maintained, pure-Dart, realtime-capable client for Linux is `firebase_dart` RTDB [V]. Firestore has none (section 4 of the deep dive).
- Data fits a tree: operation -> events (push IDs ordered by time), requests, members.
- Rules handle the authority model: GM uid is the only event writer; players write only their own request subtree. This is not anti-cheat; it blocks strangers.
- Limits to design around: about 1,000 writes/s per database, so very chatty features (cursors, typing) should not hit one database; sharding across multiple RTDB instances per project is a documented Blaze option [U]. Shallow queries and `orderByChild` need indexes in rules [V C++ note; U for `firebase_dart`].
- Trade-off: weaker queries than Firestore (public archive search, listing a user's operations). Mitigate with denormalised index nodes written by the client or a function, or Firestore REST (proven read [P]) for read-mostly archive content.

## 5. Dart Cloud Functions: what fits
- Production triggers: `onRequest`, `onCall`, `onCallWithData` only [V]. Emulator only: Firestore, RTDB, Storage triggers. Not in production: scheduler, Pub/Sub, Auth blocking, task queues [V]. Needs Dart 3.9+, Firebase CLI 15.15.0+, opt-in experiment, Blaze [V]. Functions do not show in the Firebase console, only Cloud Run in Google Cloud console [V]. `onCall` must be invoked by URL, not by name [V].
- Fits: badge token mint, claim set, payment webhooks, receipt validation, pack publish helper. Join checks and moderation moves only if the RTDB REST route is probed; otherwise they are client writes under rules (section 3), since `firebase_admin_sdk` has no RTDB admin [V].
- Does not fit: reacting to RTDB writes, scheduled cleanup, Auth-event hooks. Alternatives: design them out (clients write what functions would derive), run them as Node functions (second language; flag to R), or scheduled admin scripts run by hand.
- Plain Cloud Run (`firebase_admin_sdk` 0.5.6 server) is only needed for long-lived connections or non-HTTP work. WebSockets there bill as active while connected and cap at 60 minutes [V], which is why the relay stays on RTDB.
- Shared code: `protocol` package (Dart) is reused in the functions for validation.

## 6. Per-OS differences

| Concern | Windows | Linux | macOS / iOS / Android | Web |
|---|---|---|---|---|
| Auth/RTDB/Storage client | `firebase_dart` [P Auth] | `firebase_dart` [P] | FlutterFire or `firebase_dart` | FlutterFire (JS) |
| Firestore client | Fails to link on R's PC [P]; the Firebase C++ desktop SDK it wraps is documented as beta, "intended only for workflows during the development of your game, not for publicly shipping code" [V]; applying that to the FlutterFire plugin is an inference [U] | None | FlutterFire | FlutterFire |
| Auth persistence across restarts | Needs storage path passed to `FirebaseDart.setup` [V] | same | native | browser |
| Push notifications | in-app only (`firebase_messaging` 17.0.0 lists no Windows or Linux [V]) | in-app only | FCM | FCM (web push) |
| App Check | FlutterFire plugin lists it since 2026-04 [V]; official docs silent [U] | none | available | available |
| Custom-token login | exposed [P] | bad-token rejection normal [P]; real token untested | yes | yes |
| Build prerequisite | Short build path; MSVC; avoid FlutterFire Firestore | Flutter Linux toolchain (GTK) | normal | none |
| Storage of tokens | `FirebaseDart.setup` storage path; on-disk token is plain unless we encrypt [U] | same | Keychain / Keystore via plugin | browser |

Design rule from the deep dive stands: `session` talks to a backend port (auth, document/tree store, event stream, blob fetch). Adapters: `FirebaseDartAdapter` (Windows, Linux, optionally everything), `FlutterFireAdapter` (mobile/web/macOS if wanted), `LanAdapter`. Recommend starting with only `FirebaseDartAdapter` everywhere it runs, to have one path to test, then adding FlutterFire only where a platform needs it (web likely).

## 7. Recommendation
Items 1 and 2 are proven on Windows and native Linux for Auth + RTDB (sections 2.1, 2.3). Rules, scale and long sessions are still unprototyped.
1. Adopt `firebase_dart` (Auth + RTDB + Storage) as the client for Windows and Linux. Pin the version and keep a fork option; maintainer count is unverified [U].
2. Operations on RTDB with the tree and rules above. Claims-based roles.
3. Gateway as Dart Cloud Functions (experimental, HTTPS only, no triggers), limited to claims, custom tokens, payments and pack publishing until the RTDB REST route is probed.
4. Drop Firestore from the v1 client unless a probe shows a need; keep Firestore REST as an escape hatch.
5. Payments: web checkout via Stripe (or the Invertase extension) for physical goods and tiers on web; store IAP only if tiers are sold in mobile apps. Decision for R.
6. Keep Windows FlutterFire Auth out of the plan unless a need arises; it is the same Auth, with more native build risk.

## 8. Open items and next probes
1. **Done:** RTDB instance confirmed at `https://web-portfolio-2d5c2.firebaseio.com`; probe passed on Windows. Remaining RTDB checks: queued-write survival across an app restart, rules (auth-required reads on real data), long-session token expiry. Cloud-thread allowlist needs both `*.firebaseio.com` and `*.firebasedatabase.app`.
1b. **Probe the RTDB REST route** from a server: service-account OAuth token, `PUT/PATCH` to `<databaseURL>/path.json`, to decide whether the gateway can write RTDB.
1c. **Probe native Windows RTDB via FlutterFire** (`firebase_database` 13.0.0 lists Windows) as an alternative to `firebase_dart`.
2. **Done:** native Linux run passed (section 2.3).
3. **Server-side probe:** mint a real custom token with `firebase_admin_sdk`, sign in with it on Windows and Linux. Needs a service account or a deployed function; not available now.
4. **Token refresh and claims:** forced refresh returned the same token. Confirm that `getIdToken(true)` hits the network and picks up changed claims, and what happens after the one-hour expiry in a long session.
5. **Anonymous upgrade** via REST `accounts:update` with `idToken`, `email`, `password`, keeping the uid.
6. **RTDB rules prototype** for the operation tree and the anonymous limits; test with the emulator or the test project.
7. **FlutterFire Windows Firestore link error:** only worth chasing if Firestore returns to the plan.
8. **Payments and store policy** were not researched.

## 9. Cleanup
All probe scratch is gone: R deleted `C:\bp` and the earlier scratchpad folder; later runs used only `C:\GAMES\BARD\.scratch-probe` (deleted) and a WSL SDK (deleted). Repo has no changes; nothing committed or pushed.

## Sources
- `firebase_dart` feature support and platform notes: https://pub.dev/packages/firebase_dart
- Dart functions trigger support levels: https://github.com/firebase/firebase-functions-dart/blob/main/doc/triggers.md
- Dart functions start: https://firebase.google.com/docs/functions/start-dart ; `firebase_functions`: https://pub.dev/packages/firebase_functions
- RTDB limits: https://firebase.google.com/docs/database/usage/limits
- Security rules and Auth / custom claims: https://firebase.google.com/docs/rules/rules-and-auth ; https://firebase.google.com/docs/auth/admin/custom-claims
- Identity Toolkit REST `accounts:update`: https://cloud.google.com/identity-platform/docs/reference/rest/v1/accounts/update
- FlutterFire changelog (App Check Windows, PR #18140): https://github.com/firebase/flutterfire/blob/main/CHANGELOG.md ; pub.dev platform metadata for `firebase_database`, `firebase_app_check`, `firebase_messaging`, `cloud_functions`
- Firebase C++ desktop SDK (beta, development only): https://firebase.google.com/docs/cpp/setup
- Second-agent review: `backend-split-review.md`
- Stripe extension: https://goo.gle/334bbir
- `firebase_admin_sdk`, Cloud Run WebSockets, FlutterFire support table: see sources in `firebase-desktop-deep-dive.md`.
- Probe results: this thread, 2026-10-16.
