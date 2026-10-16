# 01. Engine (`packages/engine`)

The engine is the game. It is pure Dart, imports only the Dart SDK, performs no I/O and never reads a clock or a random source it was not handed. Given the same inputs it always produces the same outputs.

## Responsibilities

- Hold the **vocabulary** of the game: what an attribute, skill, check, condition, item, vehicle or threat class *is*, and how each computes.
- Turn **commands** into **events** (`decide`), and **events** into **state** (`evolve`).
- Roll dice through an injected, seeded RNG and record every die in the resulting event.
- Expose **read models**: pure functions that answer UI questions ("what is this agent's Evasion?") from state.

Not its job: networking, persistence, accounts, ordering of messages, who is allowed to send what (that is `session`), or presentation.

## Core loop

```
Engine(rulesPack)                                   // the pack is bound once, at construction
decide : (State, Command, Rng, IdSource) → Decision // Accepted(List<Event>) | Rejected(reason)
evolve : (State, Event)                  → State    // no RNG, no IDs, no failure path
replay : (State0, List<Event>)           → State    // fold of evolve
```

These are the same signatures as the [public API](#public-api-surface-proposed) below. `IdSource` supplies new entity IDs during `decide` only.

- `decide` is the only function that may consume randomness. It runs **only on the GM's engine** during an operation (and on any device in solo/offline prep).
- `evolve` is total and deterministic. Every client runs it. Because events carry resolved results (dice faces, totals, outcomes), replaying a log never re-rolls and history never changes.
- A rejected command produces no events. The session layer turns the rejection into a reply to whoever sent it.

## ECS model

### Entities

An entity is an `EntityId` and nothing else. IDs are opaque strings generated inside `decide` (from the operation's ID source, injected like the RNG) and recorded in the creating event, so every client agrees on them.

Entities cover agents (player characters), NPCs, adversaries, items, vehicles, artifacts, locations and scenes. What an entity *is* depends only on which components it has.

### Components

Components are immutable, typed value classes defined by the engine. Each has a stable `typeKey` used in serialization. Examples (illustrative, final list comes from the core pack work):

| Component | Holds | Rulebook source |
|---|---|---|
| `Identity` | name, kind tag, owner alias (if any) | — |
| `Attributes` | map of pack-declared attribute key → score | §3 |
| `Skills` | map of pack-declared skill key → proficiency tier key | §3, §5 |
| `Vitals` | current/max Health, current/max Sanity | §4 |
| `Defense` | DR modifiers, reactions available this round | §7 |
| `Conditions` | active conditions/afflictions with source and duration | §4 |
| `Disorders` | long-term disorders | §4 |
| `Inventory` | item entity IDs carried | §6 |
| `WeaponProfile` | damage category, range bands allowed | §6, §7 |
| `VehicleProfile` | performance category, durability category | §6 |
| `ThreatClass` | class key for adversaries | §10 |
| `Advancement` | XP available/spent, purchased upgrades | §9 |
| `Visibility` | who may see this entity and which of its components | — |
| `Position` | scene, range band to other entities (no grid assumed) | §7 |

Rules for components:

- A component never stores a value that can be derived. Health max, Sanity max, Evasion and Initiative bonus are **derived** by the engine from attributes using formulas the pack supplies (§3). They are read models, not stored fields, unless a permanent upgrade modifies them (stored as an explicit modifier, e.g. the §9 "Formidable" purchase).
- Keys inside components (`STR`, `firearms`, `proficient`) are **pack values**. The engine validates them against the active pack.

### State

```
OperationState
  ├─ meta: operation id, engine version, pack ref (id, version, content hash), settings
  ├─ stores: Map<ComponentType, Map<EntityId, Component>>   // ECS stores
  ├─ encounter: initiative order, round, whose turn (when in combat)
  ├─ pending: open action requests and checks awaiting the GM
  └─ rng: seed reference + draw counter (GM engine only uses it)
```

Stores are persistent immutable maps so `evolve` stays cheap. The choice of immutable collection implementation is internal to the engine and needs no new dependency if written by hand; if a package is wanted it goes to R first.

### Systems

A system is a pure function grouped by concern. Each system handles a subset of commands in `decide` and a subset of events in `evolve`. Systems never call each other's internals; they share only state and the pack.

| System | Handles |
|---|---|
| `CharacterSystem` | creation steps (§3), attribute/skill allocation rules, advancement purchases (§9) |
| `CheckSystem` | action requests, check requirements, resolution, opposed checks, assistance, overrides (§2, §5) |
| `VitalsSystem` | damage, DR, healing, critical injury triggers, sanity loss and recovery (§4, §7) |
| `ConditionSystem` | applying, ticking and clearing conditions, afflictions, disorders (§4) |
| `CombatSystem` | initiative, rounds, turn order, action economy (major/minor/reaction), range penalties, movement (§7) |
| `VehicleSystem` | vehicle maneuvers, crash tests, passengers (§6, §7) |
| `OccultSystem` | occult action checks, ritual time and participants, focus items, sanity cost (§8) |
| `InventorySystem` | items, equipment, transfer |
| `MessagingSystem` | in-game phone messages (see [04-session.md](04-session.md#in-game-phone)) |
| `GmSystem` | GM-only edits: spawn NPC, set value, reveal/hide, award XP, free-form narrative events |

`decide` dispatches a command to exactly one system with an exhaustive `switch` over the sealed `Command` family [V-16]. `evolve` does the same over `Event`.

## Commands and events

Both are sealed families in the engine. Each carries an `actor` (the alias or GM issuing it) and, for events, a `visibility`.

Illustrative check flow (names fixed by R's decision; fields are Proposed):

```
Player:  RequestAction(actor, description, suggestedSkill?)        → ActionRequested
GM:      RequireCheck(requestId, attribute, skill?, dc, modifiers) → CheckRequired
GM:      ResolveCheck(checkId)                                      → CheckResolved
GM:      OverrideResult(checkId, outcome, note)                     → ResultOverridden
GM:      ApplyConsequence(...)                                      → DamageApplied | SanityLost | ConditionApplied ...
```

- The GM may skip the request step (GM-initiated checks), and may set "auto-resolve" so `RequireCheck` immediately rolls. That is a GM setting stored in operation meta, not a different rule.
- `CheckResolved` carries the full breakdown: every die with its faces, which dice exploded, advantage pool and the kept result, each modifier with its source, total, DC, and the outcome band. The UI renders the breakdown; it never recomputes it.
- `ResultOverridden` never edits `CheckResolved`. Read models report "overridden" and show both.
- Consequences are separate events, so an override can change what follows without rewriting the past.

Event payloads must be self-sufficient: applying an event must not require re-running pack formulas that could change later. If a pack update changes a formula, old events still mean what they meant.

## Dice and checks (vocabulary)

The engine implements these **kinds** of mechanics from the rulebook. All numbers (dice sizes, thresholds, bonuses, DCs) come from the pack.

| Mechanic | Engine vocabulary | Values from pack |
|---|---|---|
| Skill check | `total = primary die + attribute + proficiency bonus + modifiers`, success if `total ≥ DC` (§2) | primary die size, which attribute, bonus per tier |
| Proficiency tiers | tier key → bonus expression (fixed number or die) | tiers and their bonuses |
| Difficulty categories | category key → DC | category table |
| Exploding die | on max face of the primary die, roll again and add, chaining (§2) | which dice explode (rulebook: primary only) |
| Luck advantage | roll N extra primary dice, keep the best total (§2) | N's source (rulebook: LCK) |
| Partial success | within X of the DC (§2, §4) | X |
| Fumble | total ≤ fraction of DC (§2) | fraction |
| Opposed check | both sides roll, higher wins, ties to GM (§5, §7) | — |
| Assistance | helpers roll a gate check, then add a bonus (§2, §8) | gate DC, bonus expression |
| Derived stats | formula over attributes (§3) | formulas |
| Damage | category → dice and minimum (§6), DR subtracts first (§7) | damage table, DR formula |
| Sanity check | resist roll, outcome band → full/half/none/extra loss (§4) | bands, losses |
| Range bands | band → penalty, weapon-category restrictions (§7) | bands, penalties |

A **dice expression** is engine vocabulary: a small data structure (not a string parsed at runtime) such as `Dice(count: 1, sides: 6, explode: true)`, `Const(3)`, `Sum([...])`, `KeepHighest(pool, n)`. Packs write these in data form; the engine evaluates them with the RNG and returns both the value and the breakdown.

A **formula** is engine vocabulary too: a tiny data-only expression tree over attribute references, constants and `+ − × ÷ min max floor`. No scripting language, no `eval`. This keeps packs editable by D and safe to load from the cloud.

### Rulebook gaps found while writing this

The engine can represent each variant below, but the **values** must be ruled on by R/D before the core pack is authored. Agents will not choose (CLAUDE.md §9).

1. **Proficiency bonus.** §2 gives Proficient +1d4 / Expert +1d6; §3 character creation says Proficient +3 / Expert +5; §5 says "+3 or +5"; §9 lists "+1d4" and "+1d6". Both forms are expressible; which is canonical is a rules question.
2. **Derived stat formulas.** In §3 the operator in "Health = ENDURANCE (END) ? LUCK (LCK)" and "Sanity = WISDOM (WIS) ? LUCK (LCK)" did not survive text extraction of the PDF. Needs reading from the rendered page or a ruling.
3. **Top category.** A category above S (DC 25, damage, vehicles, threat classes) uses a glyph that does not extract as text. Its key/name needs confirming.
4. **Disorder table (§4).** Roll numbers and rows are misaligned in the extracted text; needs confirming from the rendered page.
5. **Occult check attribute.** §8 gives the Occult Action Check as `1d6 + (WIL/INT) + Proficiency` and casting as `1d6 + (WIS or INT) + Skill`. Both are expressible; the canonical attribute set needs a ruling.

## RNG

- The GM engine receives an `Rng` interface. Production uses an engine-defined PRNG seeded per operation; tests use a scripted RNG that returns fixed faces.
- **Proposed:** implement the PRNG inside the engine (a small, documented, published algorithm), instead of relying on `dart:math` `Random`. The `dart:math` docs offer an optional seed but promise nothing about the sequence across platforms or SDK versions [V-15]; an engine-owned algorithm makes a seed meaningful forever and on every target.
- The implementation must use 32-bit chunk arithmetic, because on the web `int` is a 64-bit float with 53 bits of integer precision and bitwise operators truncate to 32 bits [V-14].
- Every `CheckResolved` (and any other rolling event) records the draw counter range it used. With the seed (stored GM-side) any roll can be audited. Results are never recomputed from the seed in normal play.
- The seed is GM-only data and is never sent to players.

## Versioning

- `engine` uses semantic versioning. The **major** is the engine API major that packs declare.
- Within a major: additive changes only (new optional fields with defaults, new commands/events, new components, new systems). A client that sees an event type it does not know must refuse to continue and prompt to update (protocol rule, see [03-protocol.md](03-protocol.md#version-negotiation)).
- A change that alters the meaning of existing data is a new major and goes through the migrator.
- Each major's serialized schema is written down in `packages/engine/schema/` (Proposed) as documentation and as the input the migrator's frozen copy is taken from.

### Compatibility decoding within a major (Fixed: allowed, additive-only)

R ruled that compatibility decoding within a major is allowed. Engine 1.6 must read anything engine 1.0–1.5 wrote: events, snapshots, packs. This is compatibility *within* one schema family, so it does not conflict with "zero compat code across majors".

- **Additive-only.** A minor may add optional fields (with a default used when absent), new event/command types, new components, new systems. It may never remove a field, change a field's type or meaning, or make an optional field required.
- **Decoders are tolerant of the past, strict about the future.** A decoder fills defaults for fields an older minor did not write. It rejects types from a *newer* minor it does not know (the version negotiation in [03-protocol.md](03-protocol.md#version-negotiation) prevents that case in normal play).
- **Old data is never rewritten.** Events stay as they were written; decoding upgrades them in memory only.

### Deprecation (Proposed mechanism)

R asked for a way to signal that something still works now but will change later. A new field may be intended to replace an old one that still does its job. Deprecation marks the old one so engine developers, pack authors and GMs see it coming, without breaking anything in the current major.

**What can be deprecated:** a component field, a whole component, a command or event type, a pack file key, or a pack entry (a skill, item, condition, table row).

**Deprecation record** (same shape everywhere; values below are placeholders):

```json
{
  "since": "1.4.0",
  "replacedBy": "example_component.newField",
  "removeIn": 2,
  "note": "Illustrative placeholder, not a real rules change."
}
```

| Field | Required | Meaning |
|---|---|---|
| `since` | yes | Version that introduced the deprecation, in the **scope that declares it**: an engine version for engine schema items, a pack version for pack items. |
| `removeIn` | yes | Integer major (same scope) where the item may disappear. Always a future major. |
| `note` | yes | Human-readable reason and what to do instead. |
| `replacedBy` | no | Reference to the successor, when one exists. Entries use `kind:id` (`skill:example_new_skill`); fields use `owner.field` (`example_component.newField` for engine schema, `skills.newField` for a pack file key). |

**In engine code:** deprecated Dart members carry the built-in `@Deprecated('message')` annotation, which makes the analyzer report every use [V-20]. The message repeats the record (`since`, replacement, removal major). The schema docs in `packages/engine/schema/` carry the same record so non-Dart readers see it.

**Old and new side by side.** While both exist within a major:

1. Decoders accept either. If both are present, the new one wins.
2. The engine writes the new one. Since version negotiation refuses clients older than the log requires, nobody needs the old one written.
3. Read models expose only the new one. One adapter function per deprecated item maps old → new at decode time, kept next to the decoder and deleted at the next major.

**At the next major:** deprecated items are removed. The migrator step for that major uses each `replacedBy` as the default mapping, so a deprecation written today becomes tomorrow's migration rule ([05-migrator.md](05-migrator.md)).

**Who sees what:**

| Audience | How they find out |
|---|---|
| Engine developers (R, D) | Analyzer warnings on deprecated members [V-20]; CI fails if a deprecation record is missing `since`, `removeIn` or `note` |
| Pack authors (D, GMs) | The pack validator reports each deprecated key or entry as a **warning**, never an error, with the note and removal major |
| GMs running operations | The pack-update summary and the operation's settings screen list deprecations that affect the pinned pack |
| Players | Nothing; deprecation never changes play |

Packs use the same record for their own entries: see [02-rules-packs.md](02-rules-packs.md#deprecation-in-packs).

## Public API surface (Proposed)

```dart
/// Engine entry point for one operation.
final class Engine {
  Decision decide(OperationState state, Command command, Rng rng, IdSource ids);
  OperationState evolve(OperationState state, Event event);
}

sealed class Decision {}
final class Accepted extends Decision { final List<Event> events; }
final class Rejected extends Decision { final Rejection reason; }
```

The `RulesPack` is bound when the `Engine` is constructed, so `decide`/`evolve` cannot be called against the wrong pack.

## Testing

See [08-testing.md](08-testing.md#engine). Every system is tested as *given state, when command (with scripted dice), then events*, and every event as *given state, when event, then state*.
