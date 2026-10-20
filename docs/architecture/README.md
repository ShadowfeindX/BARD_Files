# Architecture specification

Status: **reviewed by R (2026-10-20)**. Ruled items are the design; items waiting on D or on a probe are marked. Nothing here is implemented yet.

This folder describes how the B.A.R.D. Files platform is built: what each package does, how they talk to each other, and which decisions are still open. It is written so R and D can maintain the system without Claude.

## Reading order

| File | What it covers |
|---|---|
| [00-overview.md](00-overview.md) | Goals, fixed decisions, repository layout, package map and dependency rules |
| [01-engine.md](01-engine.md) | The pure-Dart game engine: entities, components, systems, commands, events, dice and checks |
| [02-rules-packs.md](02-rules-packs.md) | Rules packs and content: what the engine owns versus what packs own, versioning, the public library |
| [03-protocol.md](03-protocol.md) | Wire format shared by every client and server: envelopes, messages, versioning, visibility |
| [04-session.md](04-session.md) | The runtime layer: actors, the GM-canonical operation loop, play modes, reconnection, in-game phone |
| [05-migrator.md](05-migrator.md) | Moving an operation from engine major N to N+1 |
| [06-accounts-backend.md](06-accounts-backend.md) | Agents, aliases, anonymous accounts, badges, and the Firebase backend (`firebase_dart`, Realtime Database, Dart Cloud Functions) |
| [07-apps.md](07-apps.md) | Main app, companion app and Cloud Functions: UI layering, perspectives, platforms |
| [08-testing.md](08-testing.md) | How each package is tested in isolation |
| [09-open-decisions.md](09-open-decisions.md) | **Decisions record** of R's rulings, plus what is still pending D, held for a probe, or deferred |
| [verification.md](verification.md) | Every Dart / Flutter / Firebase claim in this spec and the source it was checked against |

## Conventions in this spec

- **Fixed** marks a decision R has already made. It is recorded, not argued.
- **Pending D** marks an item R wants D's approval on before it is designed in full. See [09-open-decisions.md](09-open-decisions.md#pending-d).
- **Held** marks an item waiting on a probe or on R's ruling of a probe-based draft. See [09-open-decisions.md](09-open-decisions.md#held).
- **Provisional** marks existing design text kept as a starting point for a Pending D item.
- **Proposed** marks a design detail R has not ruled on individually. It is not load-bearing.
- Item ids (P1, F2, FS3, B5, W1 and so on) trace each ruling to [09-open-decisions.md](09-open-decisions.md#decisions-record-ruled-by-r-2026-10-20).
- **[U]** marks a claim from the backend investigation that is still unverified.
- **[V-n]** points to a verified claim in [verification.md](verification.md). Any Dart, Flutter or Firebase statement without a tag is a design statement, not a claim about the toolkit.
- Rulebook references cite the canonical PDF (`BARD Core Rulebook.pdf`) by section number.

## Glossary

| Term | Meaning |
|---|---|
| Agent | A player's account. Owns one or more aliases. |
| Alias | A character identity belonging to an agent, locked to one campaign at a time. |
| Campaign | A long-running game run by one GM, made of operations. |
| Operation | One gameplay session (the rulebook's "mission"). Has its own event log. |
| Handler / GM | The rulebook calls the GM the Handler. This spec uses GM. |
| Command | A request to change the game ("attack this target", "require a check"). May be rejected. |
| Event | A fact that happened ("check resolved: 11, success"). Never changes once written. |
| Engine | The pure-Dart package that turns commands into events and events into state. |
| Rules pack | Versioned data (attributes, skills, tables, items, NPCs) the engine computes with. |
| Vocabulary | The kinds of things the engine understands and how they compute. Owned by the engine. |
| Values | The concrete numbers, names and tables. Owned by rules packs. |
| Perspective | What a given viewer (GM, a player, the table) is allowed to see. |
