# Review: backend-split.md

Date: 2026-10-16. Reviewer: second-agent review required by CLAUDE.md. Scope: factual claims in `backend-split.md` checked against pub.dev, Firebase and Google Cloud docs (via the Developer Knowledge API and direct fetches), plus internal consistency and coverage of R's requirements. The report was not edited.

Labels: **Confirmed** (matches a source read this review), **Wrong** (source contradicts it), **Partly** (right in part, needs a change), **Unverified** (no source found; needs a probe or a source).

## Summary
1. The core client choice holds: `firebase_dart` 1.6.2 is pure Dart and lists Windows and Linux. It supports Auth, Realtime Database and Storage, and not Firestore, Messaging or App Check.
2. **Biggest problem:** the server design assumes Dart Cloud Functions can write to Realtime Database. The `firebase_admin_sdk` page marks Realtime Database admin as **not supported**. Join/membership writes and archive moderation moves in section 3 depend on this.
3. Two specific technical errors: the anonymous-upgrade endpoint is named wrong (`accounts:signUp` should be `accounts:update`), and the App Check "not on Windows" claim conflicts with a FlutterFire changelog entry.
4. The RTDB 404 probe most likely means the test project has no RTDB instance, not a wrong URL. The next step is to check the console, not only to get the URL.
5. Recommendation 7.1 (adopt `firebase_dart` RTDB as the path) should be conditional on the RTDB probe, which has not passed.

## 1. Claim check

| # | Claim in report | Result | Source / note |
|---|---|---|---|
| 1 | `firebase_dart` 1.6.2, pure Dart, Windows and Linux | Confirmed | pub.dev: "pure dart implementation"; platforms Android, iOS, Linux, macOS, web, Windows. Latest version 1.6.2. |
| 2 | Auth, RTDB, Storage supported; Firestore/FCM/App Check not | Confirmed | pub.dev lists Authentication, Realtime database, Cloud storage. Not mentioned: Firestore, Messaging, App Check. "Not mentioned" is not proof of absence, so the report's "no FCM" is a reasonable reading. |
| 3 | Offline writes not persisted by `firebase_dart` | Confirmed | pub.dev: `setPersistenceEnabled` "query results are stored, writes not." |
| 4 | `linkWithCredential` not supported in `firebase_dart` | Confirmed | pub.dev marks `linkWithCredential` and `linkWithPhoneNumber` as not supported; `unlink` is supported. |
| 5 | `FirebaseDart.setup` storage path controls on-disk persistence | Confirmed | pub.dev: "The storage path can be null, in which case no data will be stored on disk." |
| 6 | `firebase_dart` has a single maintainer | Unverified | Page names the publisher appsup.be and a sponsor page. Did not count maintainers. |
| 7 | firebase_core 5.0.0, firebase_auth 7.0.0, cloud_firestore 7.0.0 | Confirmed | pub.dev latest versions. |
| 8 | Windows: Auth, Firestore listed; Linux not | Confirmed | firebase_auth 7.0.0 lists Windows (no Linux). cloud_firestore 7.0.0 lists Windows (no Linux). firebase_core 5.0.0 lists Windows (no Linux). |
| 9 | Dart functions: production triggers are `onRequest`, `onCall`, `onCallWithData` only | Confirmed | firebase-functions-dart triggers.md: "Only HTTPS triggers are currently supported in production." |
| 10 | RTDB, Firestore, Storage triggers | Partly | Source says these are **emulator only**, which fits the report's "not in production." Report's wording "not in production" is correct; add "emulator only." |
| 11 | Scheduler, Pub/Sub, Auth blocking, task queues not in production | Confirmed | Listed as experimental: "not currently supported by the emulator or production." |
| 12 | Dart 3.9+, Firebase CLI 15.15.0+, opt-in experiment, Blaze for deploy | Confirmed | start-dart page. Experiment flag is `firebase experiments:enable dartfunctions`. Page says the feature is "experimental and may change without notice." The report does not carry that warning into the summary. |
| 13 | Dart functions not shown in Firebase console; visible on Cloud Run functions page | Confirmed | start-dart page. |
| 14 | `onCall` must be invoked by URL, not by name | Confirmed | start-dart page: cannot be called with `httpsCallable`; use the Cloud Run URL. |
| 15 | RTDB limits: 200,000 connections, 1,000 writes/s per database | Confirmed | Limits page. Spark plan: 100 connections. |
| 16 | Sharding is a documented Blaze option | Confirmed (upgrade from [U]) | RTDB docs: on Blaze you can "create multiple databases"; limits page: "use multiple databases." |
| 17 | Cloud Run WebSockets: 60-minute cap, billed as active while connected | Confirmed | Cloud Run WebSockets page: request timeout "up to 60 minutes" (default 5 min); "A Cloud Run instance that has any open WebSocket connection is considered active." |
| 18 | `firebase_admin_sdk` 0.5.6: createCustomToken, Auth admin, Messaging supported | Confirmed | pub.dev: Authentication supported (incl. createCustomToken, setCustomUserClaims); Messaging supported; Dart 3.9+. |
| 19 | `firebase_admin_sdk` used for server RTDB writes (implied by sections 3 and 5) | **Wrong** | pub.dev marks **Realtime Database admin: not supported**. See finding W1. |
| 20 | FCM client: mobile/web only; FlutterFire Messaging N/A on Windows | Confirmed (as documented) | FCM Flutter client docs cover Android, Apple (iOS+) and Web only. Windows and Linux are not listed. |
| 21 | App Check: none on Windows/Linux; not in `firebase_dart` | **Partly / conflicting** | Official App Check page lists Apple, Android, Web, and custom backends; Windows and Linux are not listed. But the FlutterFire changelog has "(windows): add support for AppCheck for Windows (#18140)." See W3. |
| 22 | App Check: none for the gateway | **Partly** | App Check docs say it can protect "your own self-hosted backend." That applies to the gateway, so "none" is incomplete. Server-side verification in Dart is unverified. |
| 23 | Anonymous to full account via `accounts:signUp` with the anonymous ID token | **Wrong** | `accounts:signUp` only creates anonymous users (use-rest-api). Linking uses `accounts:update` (setAccountInfo) with `idToken` plus `email` and `password` ("Link with email/password"). See W2. |
| 24 | Anonymous upgrade keeps uid | Partly | Firebase docs: linked credentials make the user "identifiable by the same Firebase user ID." That supports the claim for the SDK path. The REST path is still unprobed (report's [U] is correct). |
| 25 | Firebase Storage on Linux via `firebase_dart` [U] | Partly | pub.dev lists Storage as supported and Linux as a platform. Can be relabelled as "listed, unprobed." |
| 26 | FlutterFire Windows Firestore link failure; "vendor says dev-only" | Partly | Link failure: probe result, unchanged. "Dev-only" source: the Firebase C++ desktop SDK doc says it is "a beta feature... intended only for workflows during the development of your game, not for publicly shipping code." That statement is for the C++ SDK. Attributing it to FlutterFire is an inference. See W4. |
| 27 | RTDB default URL 404 means "likely no instance" | Partly | Docs give two URL forms: `DATABASE_NAME.firebaseio.com` (us-central1) and `DATABASE_NAME.REGION.firebasedatabase.app` (other regions). The probe used both correct forms. A 404 on all three most likely means no RTDB instance exists in `web-portfolio-2d5c2`. See W5. |

## 2. Findings that need correction

**W1. Server-side RTDB writes are unsupported in the planned admin SDK.** Sections 3 (membership/join by `onCall`; archive moderation moves to `/archive/public`) and 5 ("Fits") assume the Dart gateway writes to RTDB. `firebase_admin_sdk` 0.5.6 does not support RTDB admin. Options: (a) client writes under rules, with the gateway limited to claims and validation; (b) the RTDB REST API with a service-account OAuth token, which is unprobed; (c) a Node function, which R would need to approve. Recommend a probe of (b) before the gateway design is final.

**W2. Wrong endpoint for anonymous upgrade.** Section 3 and 8.5 say `accounts:signUp` with the anonymous ID token. Correct endpoint: `https://identitytoolkit.googleapis.com/v1/accounts:update?key=...` with `idToken`, `email` and `password`. Fix both places and keep the uid probe in 8.5.

**W3. App Check on Windows: sources conflict.** The report says it is unavailable on Windows in FlutterFire. The FlutterFire changelog says Windows App Check support was added (PR #18140). The official App Check page does not list Windows. Re-check which FlutterFire version shipped it, and state both facts. Do not treat App Check as settled either way until checked.

**W4. "Vendor says dev-only" needs a correct source.** The quoted restriction is from the Firebase C++ desktop SDK doc, which is beta and development-only. Cite that doc, and mark the FlutterFire Windows inference as [U].

**W5. RTDB probe conclusion.** Given the docs' URL forms, the 404s point to a missing instance. The next step is to open the console (Realtime Database page, test project `web-portfolio-2d5c2`) and create or confirm an instance, then rerun the probe. The report's 8.1 ("get the exact databaseURL") should say that.

## 3. Internal inconsistencies

- **I1.** Section 7.1 and 7.2 recommend `firebase_dart` RTDB for operations. Section 2.1 shows the RTDB probe failed, and 8.1 lists it as not run. The recommendation should say "conditional on the RTDB probe."
- **I2.** Section 3 (join/moderation) conflicts with section 5 "Fits" once W1 is applied. The gateway's responsibilities need to be re-listed.
- **I3.** Section 1.4 and 7.3 choose Dart Cloud Functions as the gateway. Section 5 notes they are experimental and need an opt-in flag. The summary should carry that warning, since R accepted the use "where appropriate."
- **I4.** The report never says how Windows and Linux clients call `onCall` endpoints. `firebase_dart` does not list a Functions client, and `onCall` cannot be called by name. The report needs a line on the call path (plain HTTPS `POST` with the ID token, or `httpsCallableFromURL` where available). Unverified.
- **I5.** Section 4 keeps Firestore REST as an escape hatch for archive reads, while 7.4 drops Firestore. Using it means a Firestore database alongside RTDB. Flag as a decision for R.
- **I6.** The architecture spec and P12/P13 mention Firestore read rules. The report moves operations to RTDB but does not say what changes in the spec or those proposals.
- **I7.** Section 3 anonymous limits rely on `auth.token.firebase.sign_in_provider`. This matches the Firebase ID token format but was not quoted from a source in this review. Verify in the rules prototype (8.6).

## 4. Requirements not covered

- **Phone messaging to GM (R-immersion):** no row in section 3. Needs an RTDB path, player-to-GM rules and a GM inbox.
- **Offline cache for signed-in accounts (R, 2026-10-15):** the report covers an outbox for writes. It does not say how alias and pack data are cached locally for offline play, nor how a GM's local state reconciles after reconnect.
- **One alias per anonymous account:** rules can enforce this only with a concrete mechanism. The report does not show one, and RTDB rules have limited child-counting. Needs an explicit design in 8.6.
- **Archive-only logs (P12/P13):** frozen logs and plain-text renderings need write-once storage rules. Not in the report.
- **Badge login security:** the badge verifier and the service-account signing path need an owner and key handling. The report flags signing permission [U] but not key custody.

## 5. Unverified (needs a probe or source)
- Dart server RTDB writes via REST with an OAuth token (W1 option b).
- Anonymous upgrade via `accounts:update`, uid preserved (8.5).
- Functions call path from firebase_dart clients (I4).
- RTDB rule mechanism for one alias per anonymous account (section 4).
- App Check on Windows: which FlutterFire version (W3).
- Dart Cloud Functions with `firebase_admin_sdk` (server-side library compatibility inside the function runtime).
- Stripe Invertase extension details (report marks as [S]; not checked).
- Linux probe failure: the report calls it a sandbox issue. Not verified either way.

## 6. Recommended edits (for the report's author; not applied here)
1. Replace the `accounts:signUp` upgrade wording with `accounts:update` (W2).
2. Mark RTDB admin unsupported in `firebase_admin_sdk`; rewrite section 3 join/moderation rows (W1).
3. Correct the App Check row with both sources (W3).
4. Replace the "vendor says dev-only" source (W4).
5. Reword the 404 finding and 8.1 to check for an instance (W5).
6. Condition 7.1 and 7.2 on the RTDB probe (I1).
7. Add the Dart Functions experimental warning to the summary (I3).
8. Add the phone-messaging, offline-cache and alias-limit rows (section 4).

## Sources
- pub.dev: firebase_dart, firebase_admin_sdk, firebase_auth, cloud_firestore, firebase_core
- Firebase Functions for Dart start guide and trigger support table (firebase-functions-dart triggers.md)
- Realtime Database limits, sharding and URL forms (firebase.google.com/docs/database)
- Cloud Run WebSockets (run/docs/triggering/websockets)
- Identity Platform REST: use-rest-api (signUp anonymous), setAccountInfo "Link with email/password" (accounts:update)
- Firebase Auth anonymous account linking docs
- FCM Flutter client docs; App Check docs
- FlutterFire changelog (PR #18140, Windows App Check)
- Firebase C++ desktop SDK doc (beta, development-only caution)
- Developer Knowledge API queries, 2026-10-16. Direct fetch of docs.cloud.google.com failed (DNS), so Cloud Run and Identity Platform text was read from the API index.
