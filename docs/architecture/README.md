# Architecture specification

Status: **reviewed by R (2026-10-20)**. Ruled items are the design (the chapters state each ruling and cite its id); items waiting on D or on a probe are marked and listed in 09 and 10. Nothing here is implemented yet.

This folder describes how the B.A.R.D. Files platform is built: what each package does, how they talk to each other, and which decisions are still open. It is written so R and D can maintain the system without Claude.

## Reading order

| File | What it covers |
|---|---|
| [00-overview.md](00-overview.md) | Goals, fixed decisions, repository layout, package map and dependency rules |
| [01-engine.md](01-engine.md) | The pure-Dart game engine: entities, components, systems, commands, events, dice and checks |
| [02-rules-packs.md](02-rules-packs.md) | Rules packs and content: what the engine owns versus what packs own, versioning, the public library |
| [03-protocol.md](03-protocol.md) | Wire format shared by every client and server: envelopes, messages, versioning, visibility |
| [04-session.md](04-session.md) | The runtime layer: actors, the GM-canonical episode loop, play modes, reconnection, in-game phone |
| [05-migrator.md](05-migrator.md) | Moving an episode from engine major N to N+1 |
| [06-accounts-backend.md](06-accounts-backend.md) | Agents, aliases, anonymous accounts, badges, and the Firebase backend (`firebase_dart`, Realtime Database, Dart Cloud Functions) |
| [07-apps.md](07-apps.md) | Main app, companion app and Cloud Functions: UI layering, perspectives, platforms |
| [08-testing.md](08-testing.md) | How each package is tested in isolation |
| [09-open-decisions.md](09-open-decisions.md) | What is still open for R and D on the platform side: items waiting on D or R, held for a probe, deferred, known issues, unproven claims. The record of rulings is in [decision-record.md](decision-record.md) |
| [decision-record.md](decision-record.md) | **Decision record**: every ruling by R and D with id, date and rationale |
| [10-waiting-on-d.md](10-waiting-on-d.md) | **Waiting on D (and R)**: unanswered questions, D's homework, items marked Later, and R's open items, each with its default (an assumption) and what changes when it is ruled |
| [11-supplemental-features.md](11-supplemental-features.md) | D's supplemental features as ruled by R: fictional profiles, clearance tiers, public badge and sign-in code, invite links, stat-gated broadcast, moderation, panic button, companion app; items waiting on the operation/mission model |
| [12-firestore-collections.md](12-firestore-collections.md) | **Firestore collections** (Proposed): names, document shapes, draft rules, composite indexes, emulator test plan, questions for R |
| [verification.md](verification.md) | Every Dart / Flutter / Firebase claim in this spec and the source it was checked against |

## Conventions in this spec

- **Fixed** marks a decision R has already made. It is recorded, not argued.
- **Pending D** marks an item R wants D's approval on before it is designed in full. See [09-open-decisions.md](09-open-decisions.md#pending-d).
- **Held** marks an item waiting on a probe or on R's ruling of a probe-based draft. See [09-open-decisions.md](09-open-decisions.md#held).
- **Provisional** marks existing design text kept as a starting point for a Pending D item.
- **Proposed** marks a design detail R has not ruled on individually. It is not load-bearing.
- Item ids (P1, F2, FS3, B5, W1, R-A1 and so on) are plain tags. They trace each ruling to [decision-record.md](decision-record.md#decisions-record-ruled-by-r-2026-10-20).
- **[U]** marks a claim from the backend investigation that is still unverified.
- **[V-n]** points to a verified claim in [verification.md](verification.md). Any Dart, Flutter or Firebase statement without a tag is a design statement, not a claim about the toolkit.
- Rulebook references cite the canonical PDF (`BARD Core Rulebook.pdf`) by section number.

## Glossary

| Term | Meaning |
|---|---|
| Agent | A player's account. Owns one or more aliases. |
| Alias | A character identity belonging to an agent, locked to one campaign at a time. May appear in any number of operations and missions at the Handler's discretion. A character is created as an agent alias, an Occult Organization member or a SKALD (civilian). |
| Campaign | A series of operations managed by a GM. Top of the four levels: Campaign > Operation > Mission > Episode (R and D, 2026-11-03). |
| Operation | D's story arc only: a long-horizon goal, a collection of missions (1 to 10 on average), managed by a Handler; operations run one after another and missions may run in parallel (D, 2026-10-29; R and D, 2026-11-03). It is not the unit of live play; that is the Episode. |
| Mission | A scenario or objective the agents try to complete, played across a series of episodes (1 to 3 on average). |
| Episode | One sitting of play (1 to 3 hours on average), the lowest level. It owns one event log, one live RTDB tree, one sembast file and one host (R and D, 2026-11-03). Each of the four levels is archived. It is called an Episode, not a session, to avoid confusion with the network *session* (the `session` package, the session host, sign-in sessions). |
| Handler / GM | The rulebook calls the GM the Handler. D (2026-10-22) uses both: the GM runs a campaign; the Handler is the GM's persona managing one operation, created per campaign and not tied to the GM's account (FD-X4, R-A4). This spec writes GM unless the persona is meant. |
| Command | A request to change the game ("attack this target", "require a check"). May be rejected. |
| Event | A fact that happened ("check resolved: 11, success"). Never changes once written. |
| Engine | The pure-Dart package that turns commands into events and events into state. |
| Rules pack | Versioned data (attributes, skills, tables, items, NPCs) the engine computes with. |
| Vocabulary | The kinds of things the engine understands and how they compute. Owned by the engine. |
| Values | The concrete numbers, names and tables. Owned by rules packs. |
| Perspective | What a given viewer (GM, a player, the table) is allowed to see. |

*Naming note.* R and D ruled the tree Campaign > Operation > Mission > Episode on 2026-11-03. Chapters 01 to 08 and the developer guide now say "episode" for the unit of live play. The code and the RTDB live tree (`/episodes/$ep`) use the same name since the rename on 2026-11-03; the v1 wire names (`startOperation`, `operationStarted`, the `operationId` field and the envelope's `op` key) are kept until an engine major bump, because stored logs are frozen per major ([05](05-migrator.md)). The word "session" is kept only for the network, host and connection layer: the `session` package, the session host, `SessionRejection`, sign-in sessions and [04-session.md](04-session.md).
