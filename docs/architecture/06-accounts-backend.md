# 06. Accounts and backend

## Backend role (Fixed)

Accounts, session persistence and relay, rules pack distribution, information dissemination (news, D's announcements), payments. The backend **never runs game rules**: `apps/server` never imports the engine; it depends on `protocol` and a server-side Firebase admin library (see dependency rules in [00-overview.md](00-overview.md#dependency-rules)).

Firebase first: Authentication, Cloud Firestore, Hosting. Any Dart server code targets Cloud Run. Dart's own server guidance recommends Cloud Run for custom containers, long-running processes and WebSocket connections [V-11].

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
- **Anonymous accounts** (Fixed): can join any session, have exactly one alias, cannot GM, host or create content. Firebase Auth supports anonymous sign-in and later linking a real credential to the same account, keeping its data [V-8]. The app offers that upgrade.
- Anonymous data does not survive clearing local storage or switching devices [V-8]; the UI says so before an anonymous player invests in a character.
- Enforcement is twofold: the session refuses host/GM/content commands from anonymous agents, and backend security rules refuse the corresponding writes using `request.auth.token.firebase.sign_in_provider != "anonymous"`, the pattern Firebase's security checklist recommends [V-8][V-9].
- **One alias per anonymous account** is enforced in three places:
  1. **Backend (authoritative for cloud accounts).** An anonymous account's alias must use the fixed document ID `aliases/anon_{uid}`. The security rule on `aliases/{aliasId}` allows an anonymous caller to create only that one ID, so a second alias is impossible. Full accounts use generated IDs.
  2. **App.** The account repository hides "create alias" for anonymous agents once `anon_{uid}` exists and offers the upgrade instead.
  3. **Session (local and LAN play without the backend).** A guest agent identity carries `kind: anonymous`; `OperationHost` refuses a `hello` that presents a second alias for the same anonymous agent id.
- When an anonymous account is upgraded by linking a credential [V-8], its `anon_{uid}` alias is kept as-is; later aliases use generated IDs.

## Badges (Fixed concept, Proposed mechanism)

A badge is a printable/scannable code (for example a QR on a physical agent badge) that signs an agent in.

- The badge encodes an opaque, revocable badge token, never a password.
- Scanning sends the token to the Cloud Run service, which checks it and returns a Firebase custom token; the app signs in with it. Firebase rules see `sign_in_provider == "custom"` [V-9]. The exact custom-token minting API is checked against Firebase docs at implementation time.
- Badges are optional, per agent, listed and revocable from account settings.
- Offline: a badge cannot create a new sign-in without the backend. An agent already signed in on that device keeps working from the local cache.

## Offline accounts (Fixed requirement)

A signed-in account works offline from a local cache. The app keeps its own local account record (profile, aliases, campaigns, pinned packs, operation logs) in the local store chosen in [09-open-decisions.md](09-open-decisions.md#3-persistence), and does not depend on Firebase SDK caching for game data. Firestore's own offline cache is on by default on Android and Apple platforms and off by default on the web [V-6]; it is useful for account documents but is not the operation store.

## Firestore data model (Proposed)

```
agents/{uid}                                  profile, kind, settings
agents/{uid}/badges/{badgeId}                 hashed token ref, created, revoked
aliases/{aliasId}                             owner uid, campaignId, public card
campaigns/{campaignId}                        gm uid, name, members, packRefs, settings
campaigns/{campaignId}/transfers/{id}         alias transfer requests
operations/{opId}                             campaignId, gm uid, engine version, packRef, status, lastSeq
operations/{opId}/events/{batchId}            batched events (seq range), written by GM only
operations/{opId}/snapshots/{seq}_{chunk}     chunked snapshots, written by GM only
operations/{opId}/textlog/{audience}_{batchId}  narrated text lines for one audience (gm, public, alias), written by GM only
operations/{opId}/requests/{requestId}        player requests, written by the requesting alias's owner
operations/{opId}/signaling/{peerId}          WebRTC offer/answer/candidates (P2P mode only)
packs/{packId}/versions/{version}             manifest + storage refs; immutable once published
library/{itemId}                              submitted content, verification state set server-side
news/{postId}                                 information dissemination
```

- Events are batched because a Firestore document is limited to 1 MiB [V-7].
- **Per-audience storage (Proposed).** The GM writes event batches and text-log batches already filtered per audience, one document per audience per batch, tagged with an `audience` field. Read rules allow the GM everything, members `public`, and an alias owner only that alias's audience, so GM-only events and text are never stored where a player's account can read them.
- **Archived operations (Proposed).** A migrated N-major operation keeps its document and id with `status: archived`; its frozen events and text log stay in its subcollections. The N+1 operation is a new document whose genesis event lists the archives.
- Security rules: only the operation's GM uid writes `events`, `snapshots` and `textlog`; a request's `from` alias must belong to `request.auth.uid`; library `verification` is writable only by an admin custom claim [V-9]. Rules have a cap on `get()`/`exists()` lookups per request (10 for single-document requests) [V-7], so rules read at most the operation document plus one alias document.
- Firestore resolves multiple offline changes to the same document as last-write-wins [V-6]. The design avoids depending on that: each event batch, request and snapshot chunk is its own new document, and only the GM writes the log.

## Relay

In network-hosted mode the backend relays and persists (Fixed). Two candidate relays exist and both fit the same `Transport` interface; the choice is part of the open networking decision ([09-open-decisions.md](09-open-decisions.md#4-networking-and-sync)):

1. **Firestore as relay.** GM writes event batches; participants listen. Players write requests; the GM listens. No custom server.
2. **Cloud Run WebSocket relay.** `apps/server` forwards frames between GM and players and appends batches to Firestore for persistence. Uses the shared `protocol` package and a server-side Firebase admin library for the Firestore writes (new dependency, needs R's approval; see [00-overview.md](00-overview.md#dependency-rules)).

## Desktop platform constraint

Firebase's Flutter plugins for Firestore and Auth support iOS, Android and web; on macOS and Windows they are marked beta, Firebase on Windows is not intended for production (local development only), and Linux is not listed [V-10]. Since all Flutter targets are required (Fixed), desktop builds need a backend path that does not depend on those plugins. This is raised in [09-open-decisions.md](09-open-decisions.md#concerns-raised) with a recommendation. The architecture already isolates the backend behind a `BackendGateway` interface in the proposed `backend` package, so a desktop implementation (for example, talking to Cloud Run over HTTPS/WebSocket) can be swapped in without touching session or engine.

## Payments

Payments are a backend role (Fixed) but nothing about products, providers or entitlements is specified yet. The architecture reserves an `Entitlements` read model in the app layer (what content an agent may use) fed by the backend. No provider is assumed. Listed in [09-open-decisions.md](09-open-decisions.md#concerns-raised).

## Environments

Firebase's security checklist recommends separate development, staging and production projects and using the Local Emulator Suite for development [V-19]. Proposed: three Firebase projects, with the emulator used by `backend` integration tests and security-rules tests.
