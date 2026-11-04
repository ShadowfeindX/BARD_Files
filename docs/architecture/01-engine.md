# 01. Engine (`packages/engine`)

The engine is the game. It is pure Dart, imports only the Dart SDK, performs no I/O and never reads a clock or a random source it was not handed. Given the same inputs it always produces the same outputs.

## Responsibilities

- Hold the **vocabulary** of the game: what an attribute, skill, check, condition, item, vehicle or threat class *is*, and how each computes.
- Turn **commands** into **events** (`decide`), and **events** into **state** (`evolve`).
- Roll dice through an injected, seeded RNG and record every die in the resulting event.
- Expose **read models**: pure functions that answer UI questions ("what is this agent's Evasion?") from state.
- Provide the **event narrator** (Fixed, P12): a pure function that turns an event into the plain-text lines shown in the in-game log, one variant per perspective (GM, public, redacted, specific aliases), using the pack's `strings/`. Its output is stored as the episode's text log during play, which is what survives a major migration ([05-migrator.md](05-migrator.md#archived-logs-fixed-ruled-by-r)). Narration runs after the GM confirms a consequence batch (P12, amended by F2), never on held events.

Not its job: networking, persistence, accounts, ordering of messages, who is allowed to send what (that is `session`), or presentation.

## Core loop

```
Engine(rulesPack)                                   // the pack is bound once, at construction
decide : (State, Command, Rng, IdSource) → Decision // Accepted(List<Event>) | Rejected(reason)
evolve : (State, Event)                  → State    // no RNG, no IDs, no failure path
replay : (State0, List<Event>)           → State    // fold of evolve
```

These are the same signatures as the [public API](#public-api-surface-proposed) below. `IdSource` supplies new entity IDs during `decide` only.

- `decide` is the only function that may consume randomness. It runs **only on the GM's engine** during an episode (and on any device in solo/offline prep).
- `evolve` is total and deterministic. Every client runs it. Because events carry resolved results (dice faces, totals, outcomes), replaying a log never re-rolls and history never changes.
- A rejected command produces no events. The session layer turns the rejection into a reply to whoever sent it.

## ECS model

### Entities

An entity is an `EntityId` and nothing else. IDs are opaque strings generated inside `decide` (from the episode's ID source, injected like the RNG) and recorded in the creating event, so every client agrees on them.

Entities cover agents (player characters), NPCs, adversaries, items, vehicles, artifacts, locations and scenes. What an entity *is* depends only on which components it has.

### Components

Components are immutable, typed value classes defined by the engine. Each has a stable `typeKey` used in serialization. Examples (illustrative, final list comes from the core pack work):

| Component | Holds | Rulebook source |
|---|---|---|
| `Identity` | name, kind tag, owner alias (if any) | — |
| `Attributes` | map of pack-declared attribute key → score | §3 |
| `Skills` | map of pack-declared skill key → proficiency tier key (a skill itself is defined by the pack, see below) | §3, §5 |
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
- A **skill** (F3) is defined by the pack with: name, description, category, attribute and proficiency. The category is one of five and is organizational only: it has no effect on rules. The engine does not model "allowed uses" for a skill (dropped from `skills.json`).

### State

```
EpisodeState
  ├─ meta: episode id, engine version, pack ref (id, version, content hash), settings
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
| `VitalsSystem` | damage, DR, healing, sanity loss and recovery (§4, §7); 0 Health is death and 0 Sanity passes the character to the Handler (G7, below); no critical-injury triggers (cut, C1) |
| `ConditionSystem` | applying, ticking and clearing conditions, afflictions, disorders (§4) |
| `CombatSystem` | initiative, rounds, turn order, action economy (one major, one minor, one reaction by default, G10), range penalties, movement (§7) |
| `VehicleSystem` | vehicle maneuvers, crash tests, passengers (§6, §7) |
| `OccultSystem` | Settled by D (2026-10-22): one "cast magic" roll, no spell list; the Handler sets the final DC; ritual time, helpers and focus items are Handler guidance; sanity cost follows the effect (M2, M3; see [Magic rulings](#magic-rulings-m3-focus-items-and-artifacts)). The focus-item reduction is not ruled ([10](10-waiting-on-d.md)). |
| `InventorySystem` | items, equipment, transfer |
| `MessagingSystem` | in-game phone messages (see [04-session.md](04-session.md#in-game-phone)) |
| `TableSystem` | rolls on the pack's random tables (`RollTable` → `TableRolled`, R-B2): the seeded RNG rolls the table's dice, the total picks one row, and the event carries the faces, total, the table's lead-in and the row text. A roll, never held for review (F2). Players read only the fiction (lead-in, then row); the GM's line has the dice; a redacted roll shows players a redaction bar (R, 2026-11-03). Table content is D's; the engine ships no rows |
| `GmSystem` | GM-only edits: spawn NPC, set value, reveal/hide, award XP, free-form narrative events |

`decide` dispatches a command to exactly one system with an exhaustive `switch` over the sealed `Command` family [V-16]. `evolve` does the same over `Event`.

## Commands and events

Both are sealed families in the engine. Each carries an `actor` (the alias or GM issuing it) and, for events, a `visibility`.

Illustrative check flow (names and fields are Proposed; the consequence step is gated by GM review per F2):

```
Player:  RequestAction(actor, description, suggestedSkill?)        → ActionRequested
GM:      RequireCheck(requestId, attribute, skill?, dc, modifiers) → CheckRequired
GM:      ResolveCheck(checkId)                                      → CheckResolved
GM:      ApplyConsequence(...)                                      → (held for GM review) → DamageApplied | SanityLost | ConditionApplied ...
```

- The GM may skip the request step (GM-initiated checks), and may set "auto-resolve" so `RequireCheck` immediately rolls. That is a GM setting stored in episode meta, not a different rule.
- `CheckResolved` carries the full breakdown: every die with its faces, which dice exploded, advantage pool and the kept result, each modifier with its source, total, DC, and the outcome band. The UI renders the breakdown; it never recomputes it.
- Nothing edits `CheckResolved`. The GM's control is over consequences, not rolls: there is no outcome override of a resolved roll (F2 replaces the earlier `ResultOverridden` proposal).
- Consequences are separate events, so a GM edit changes what follows without rewriting the roll.
- **GM review gate (F2, option A, ruled by R 2026-10-20).** Consequence events (damage, sanity loss, conditions, and any category value) are produced by `decide` but held as a GM-only pending batch in `EpisodeHost` ([04-session.md](04-session.md)). The GM confirms the batch or edits it; an edit is recorded on the event as `overriddenFrom` (the original value) and sits beside it. Only then do sequence numbers, storage, narration and broadcast happen. A per-episode auto-confirm setting skips the wait (F2; R ruled 2026-11-04 it is separate from the Q5 request setting in [04](04-session.md#settings-resolution-r-a1-r-c1)). **Death at 0 Health goes through the gate (R7, ruled 2026-10-27):** it is part of the confirmed damage batch, so the Handler can edit the damage before the character dies; the Handler's own `KillCharacter` is not gated. Rolls are never gated or altered: `CheckResolved` broadcasts immediately, the GM never influences dice, and rolled faces are never changed. This covers rulebook decision 21.
- **Reserved field `source` on `CheckResolved` (concern 7).** Values `rng` | `entered`, plus who entered the faces (GM or an alias). The field is reserved now so logs written today stay valid. The feature (players entering physical dice faces, behind a GM setting that is off by default) is approved by D (2026-10-22) and built after the demo (see [the record](decision-record.md#decisions-record-ruled-by-d-2026-10-22)). Proposed: `ResolveCheck` takes optional `faces`, validated against the dice the check would roll and refused unless `EpisodeSettings.allowPhysicalDice` (default `false`) is on; entered faces are recorded with `source: entered` and who entered them, and, like app rolls, are never re-rolled or changed. The setting follows the settings levels ([04](04-session.md#settings-resolution-r-a1-r-c1)).

Event payloads must be self-sufficient: applying an event must not require re-running pack formulas that could change later. If a pack update changes a formula, old events still mean what they meant.

## Dice and checks (vocabulary)

The engine implements these **kinds** of mechanics from the rulebook. All numbers (dice sizes, thresholds, bonuses, DCs) come from the pack.

| Mechanic | Engine vocabulary | Values from pack |
|---|---|---|
| Skill check | `total = primary die + attribute + proficiency bonus + modifiers`, success if `total ≥ DC` (§2) | primary die size, which attribute, bonus per tier |
| Proficiency tiers | tier key → bonus expression; the proficiency bonus is additional dice, Proficient +1d4 and Expert +1d6 (G16) | tiers and their bonus dice |
| Difficulty categories | category key → DC | category table |
| Exploding die | on max face of the primary die, roll again and add, chaining (§2) | which dice explode (rulebook: primary only) |
| Luck advantage | roll N extra primary dice, keep the best total (§2). Replaced by flashback (G2, FB1): nothing is built, the pack block stays pending | N's source (rulebook: LCK) |
| Partial success | within X of the DC (§2, §4) | X |
| Fumble | total ≤ fraction of DC, rounded down (§2; G1, K1) | fraction |
| Opposed check | both sides roll, higher wins, ties to GM (§5, §7) | — |
| Assistance | helpers roll a gate check, then add a bonus (§2, §8); the bonus is the helper's flat attribute score and the helper count is capped at the roller's score + 1 (D, 2026-10-22; was `1d6 + var(helperSkillBonus)`) | gate DC, cap, bonus expression |
| Derived stats | formula over attributes (§3) | formulas |
| Damage | category → dice and minimum (§6); MIN is a floor on the total (G9); DR subtracts first (§7) | damage table, DR formula |
| Sanity check | resist roll against the DC for the current Sanity band; outcome band → full/half/none/extra loss (§4, G5) | bands, losses |
| Range bands | band → penalty, weapon-category restrictions (§7) | bands, penalties |

A **dice expression** is engine vocabulary: a small data structure (not a string parsed at runtime) such as `Dice(count: 1, sides: 6, explode: true)`, `Const(3)`, `Sum([...])`, `KeepHighest(pool, n)`, `Var(key)`. Packs write these in data form; the engine evaluates them with the RNG and returns both the value and the breakdown.

A **formula** is engine vocabulary too: a tiny data-only expression tree over attribute references, constants, `var` nodes and `+ − × ÷ min max floor`. No scripting language, no `eval`. This keeps packs editable by D and safe to load from the cloud. (P4, approved by R: data-only expressions and formulas, no scripting. R's reason: a new mechanic usually arrives with other structural engine changes anyway.)

A **condition** (approved by R with the stat-gated broadcast, 11 §Messaging) is a yes-or-no test built the same data-only way: `{"type":"compare","op":<lt|le|eq|ne|ge|gt>,"left":<formula>,"right":<formula>}`. Both sides are formulas with no dice and no `var`. It is a separate node kind from expressions, since it yields a yes or no rather than a number. The JSON form, the six operators and the absence of combinators (and, or, not) are Proposed.

**The `var` node** (approved by R 2026-10-20) is `{"type":"var","key":<name>}`: a named number the engine supplies at evaluation time, so a pack can refer to a value that exists only in the moment of the roll or purchase. The approved placements are:

| Placement | Expression | `var` supplied by the engine |
|---|---|---|
| Advancement, attribute purchase XP (`advancement.json`) | `10 × var(newScore)` | the attribute score being bought |
| Assistance bonus (`difficulty.json`) | the helper's attribute score (D, 2026-10-22; replaces `1d6 + var(helperSkillBonus)`; key name Proposed, `helperAttribute`) | the helper's score in the check's attribute |

Any new `var` key or placement goes to R first.

### Rulebook gaps and settled rulings

The engine can represent each variant; the **values** come from the rulebook as ruled. Agents do not choose (CLAUDE.md §9). Settled by R (F1, 2026-10-20):

1. **Proficiency bonus (settled, G16).** The bonus is additional dice: Proficient +1d4, Expert +1d6. The flat +3/+5 wording in §3 and §5 is not canonical.
2. **Derived stats (settled).** Health = END × LCK. Sanity = WIS × LCK.
3. **Top category (settled, G12).** The category above S is Cat-Ω. Its values (DC, damage, vehicle and threat-class values) are decided by the Handler, not fixed by the book.
4. **Disorder table (settled).** §4 reads as a clean table of rolls 1 to 6.
5. **Occult check attribute (settled by D, 2026-10-22, C5/G6).** WIL by default, or the attribute of the skill the player names. "Cast magic" is one roll: the Handler sets the final DC from the circumstances (time, helpers, focus items). See the D rulings below.

Settled by D (2026-10-22 unless dated; the record is [decision-record.md](decision-record.md#decisions-record-ruled-by-d-2026-10-22)). Shapes named here are Proposed; the rulings are Fixed:

6. **Rounding (K1).** "When rounding in B.A.R.D. we ALWAYS round to the benefit of the player." Every rounding in the engine or a pack names its direction (`rounding: "down" | "up"` beside the fraction, Proposed). D agreed the list on 2026-10-29 (FD-K1): damage to players rounds down, healing and XP round up, sanity loss rounds down, and thresholds that cause bad outcomes (the fumble threshold) round down.
7. **"Roll" means the total (K2, G1)** in most cases, unless otherwise specified (D). A fumble is a total at or below 25% of the DC, rounded down.
8. **Exploding dice (G3).** The primary d6 and damage dice; not the proficiency die or any other.
9. **Assistance (G4, G18).** Helpers allowed = the roll's attribute score + 1; each helper adds their flat attribute score. The `helperSkillBonus` variable above is replaced. Proposed pack shape: `assistance.cap` `{"type": "attributePlus", "plus": 1}`; refusal code `tooManyHelpers`. Whether the helper still passes the Cat-D gate check first, and whether an untrained character may help, is not ruled ([10](10-waiting-on-d.md)).
10. **Sanity (G5).** The Handler sets the loss; the book's ranges are suggestions and nothing rolls automatically. The resist DC follows current Sanity: 0 to 20% of maximum is Cat-S (DC 21), 21 to 40% Cat-A, 41 to 60% Cat-B, 61 to 80% Cat-C, 81 to 100% Cat-D (D agreed the bands on 2026-10-29, FD-S1). Half loss rounds down. In an anomalous attack a partial success halves the loss, or the Handler sets a narrative effect. A fumbled resist roll costs the full loss plus 1, and the Handler describes the complication. A failed disorder check rolls 1d6 on the disorder table. Proposed pack shape: `sanity_events.json` `pick: "gm"`, `resistDc.bands`, `halfRounding: "down"`, `fumbleExtra: 1`; `disorders.json` `rollDie` 1d6. D will supply the reworked sanity and disorder tables; until then the book's ranges stay as suggestions and the pack keeps `null` where D has not given a value.
11. **Death (G7).** 0 Health is death (the app shows a death screen); 0 Sanity passes the character to the Handler's control, very likely ending in a bad narrative event and death; the Handler can kill a character at any time. The Handler chooses the DC and the effect from a list of automated effects (the engine's consequence events: damage, sanity loss, condition, modifier) plus a custom text option. The 1.3.1 critical-injury table is cut (C1). Death at 0 Health goes through the review gate (R7, below). Proposed: `KillCharacter` (Handler), `CharacterDied`, `ControlTransferred`.
12. **Weapon MIN (G9).** A floor on the total damage, modifiers included; the melee floor is the greater of the weapon's MIN and the STR score (Proposed pack shape `meleeFloor: "max(min, STR)"`). Weapon MIN values stay `null` where D has not given them; whether Strength also adds to damage dice is not ruled.
13. **Turn (G10).** One Major, one Minor and one reaction (Dodge or Parry) between turns by default (Proposed `combat.json` `actionsPerTurn: {major: 1, minor: 1, reaction: 1}`); an item, bonus or skill the Handler grants may raise any of them (Proposed component `ActionBudgetBonus`). What Aim and the reactions answer, and when the reaction refreshes, are not ruled.
14. **Creation (G19).** Limits by character kind, not exact totals. Agent alias or Occult Organization member: at most 20 attribute points, one attribute at 5, two at most at 4, at least 1 Expert, Proficients optional. SKALD (civilian character, not an agent alias): at most 15 points, one attribute at most 4, two at most 3; D wrote "1 expertise and 1 proficiency and neither is mandatory". Proposed: pack creation profiles `agent` and `skald` replace the single attribute range and proficiency counts, and `CharacterSystem` takes a profile. The remaining caps, the minimum score and how many skills an agent may take are not ruled.
15. **Advantage and disadvantage (G2)** are replaced by flashback (FB1, [below](#flashback-fb1)); nothing is built for them, and the `luckAdvantage` block stays pending.
16. **Human adversaries (HA1, FD-H1).** Human adversaries get their stats from weapons and gear exactly like players: attributes, skills and `items/`. The enemy defense and attack numbers (G11, Later) apply only to supernatural classes.

### Magic rulings (M3, focus items and artifacts)

Ruled by D (2026-10-22, M3; 2026-10-29, FD-M2). `OccultSystem` is one roll kind with a Handler-set DC; the rest is how it is paid for:

- **When sanity is checked (M3a).** The Handler decides when a sanity check is needed (for example when casting against a supernatural entity); the default is on a success only. A cast carries a Handler flag that requires the check on any cast (Proposed `sanityCheckOn: "success"`).
- **Who pays (M3b).** Every player present at the ritual pays sanity on a success, whether or not they cast; on a fail only the players taking part in the cast pay. The cost is the result of the effect going off, not a cost of the magic ("people go crazy when they see a demon appear, whoever summoned it"). This replaces the book's "each caster pays half". Proposed `sanityPayers: {onSuccess: "present", onFail: "participants"}`; the cast records who is present and who takes part, and amounts are suggested per payer through the review tray.
- **Training (M3d).** Casting normally needs skill, training, knowledge or guidance; a high-affinity individual (high WIL, related skills, Handler discretion) may cast under extreme circumstances or spontaneously. A missing prerequisite is refused unless the Handler allows it on that cast (Proposed `RejectionCode` `missingOccultTraining` with a Handler allowance flag). No numeric affinity threshold is ruled.
- **Focus item and artifact (FD-M2, R-B1).** They are different things. A **focus item** is a personally relevant item (a favourite trinket, an item from childhood) that grounds the agent and reduces the Sanity cost of certain actions. An **artifact** is a dangerous, powerful item with its own will: using it costs Sanity and takes the player's mental fortitude. The book labels the artifact rule "Focus Items" (Section 8, Casting & Rituals: +1d6, +2 Sanity per category above D). Pack keys: `artifact` holds the book's rule; `focusItem` is new and stays `null` until D rules the reduction. Using both together makes any failure catastrophic; the outcome comes from a random table (the `tables/` kind and `TableSystem`, R-B2), whose content is D's. The focus-item reduction, who approves a focus item, and the artifact's resist roll are not ruled.
- **Cast DC.** All factors (time, helpers, focus items, circumstances) are folded into the one DC the Handler types. `ritualDefaults` stays in `occult.json` as Handler guidance only, not as engine rules.

### Flashback (FB1)

D asked (2026-10-22) for flashback to replace advantage and disadvantage: a player adds a bonus to a **failed** roll by giving a narrative reason, from past preparation, why they would have succeeded. R ruled (R8, 2026-10-27) that, because rolled faces are never altered (F2), a flashback is an additive, logged event beside the roll: the original roll stays as rolled and the bonus is shown next to it. Proposed names: `UseFlashback` command and `FlashbackUsed` event; the narrator and the `ui_kit` breakdown show both. The size of the bonus, how often it may be used, who approves the reason, whether it can rescue a fumble, and what happens to Luck's extra dice are not ruled ([10](10-waiting-on-d.md)); nothing is built.

### Rulings that need code (Proposed rows)

None of these is built. Names and shapes are Proposed; the ruling behind each is stated above or in the chapter named. Each becomes a workstream row, sequenced by R.

| Ruling | Proposed code | Where it is described |
|---|---|---|
| Cast magic is one roll (M2) | A `castMagic` kind on `RequireCheck` or a new command; sanity suggested through `VitalsSystem`; `occult.json` parser replaces the raw `occultPending` | this chapter, [02](02-rules-packs.md#pack-side-rulings-by-file) |
| Sanity payers and training (M3) | Present and participating lists on the cast; `missingOccultTraining` refusal with a Handler allowance | this chapter |
| Death and control (G7, R7) | `KillCharacter` (Handler, not gated), `CharacterDied`, `ControlTransferred`; death screen in `ui_kit` | this chapter, [04](04-session.md#the-episode-loop-gm-canonical-fixed), [07](07-apps.md#rulings-that-shape-screens) |
| Assistance (G4, G18) | `CheckSystem` assistance with `tooManyHelpers` and one breakdown line per helper; `var` `helperAttribute` replaces `helperSkillBonus` | this chapter, [02](02-rules-packs.md#named-variables-in-pack-formulas-fixed) |
| Turn (G10) | `CombatSystem` action tracking, `ActionBudgetBonus` | this chapter |
| Creation profiles (G19) | `CharacterSystem` creation takes a profile; SKALD as a character kind ([11](11-supplemental-features.md#agents-aliases-and-profiles)) | this chapter, [02](02-rules-packs.md#pack-side-rulings-by-file) |
| Name reveals (N1) | `RevealName`, `NameRevealed`, `KnownAs`; narrator takes a viewer | [04](04-session.md#names-in-the-log-n1) |
| Flashback (FB1, R8) | `UseFlashback`, `FlashbackUsed` | this chapter |
| Physical dice (C7) | `ResolveCheck` takes optional `faces`; `EpisodeSettings.allowPhysicalDice` (default `false`) | this chapter (Reserved field), [04](04-session.md#play-modes) |
| Fumble (G1) | `CheckOutcome.fumble`, narrator line, `ui_kit` label | this chapter |

With the proficiency question ruled, the worked examples in §2 are unblocked as tests ([08-testing.md](08-testing.md#engine)).

## RNG (fixed)

Ruled by R 2026-10-20 (P5).

- The GM engine receives an `Rng` interface and stays SDK-only. Production uses the pub package `xrandom` (0.7.2, revercode.com), class **`Xoshiro128pp`**, seeded per episode. It is wrapped by an adapter in `session` that implements the engine's `Rng`; the engine itself never imports `xrandom`. Tests use a scripted RNG that returns fixed faces.
- Why not `dart:math` `Random`: its docs offer an optional seed but promise nothing about the sequence across platforms or SDK versions [V-15]. `xrandom` marks `Xoshiro128pp`, `Xorshift32` and `Xorshift128` as working on JS and tests its generators against C reference output in VM and Node.js modes, which addresses the web's 53-bit integer limits and 32-bit bitwise truncation [V-14][V-28].
- Use the class `Xoshiro128pp` by name. The aliases `Xrandom`, `Drandom` and `Qrandom` are not used.
- The version is pinned exactly (F5 standing rule: re-verify on pub.dev before it enters a pubspec). **Known-seed test vectors** run on native and on web [V-28], and fail the build if the sequence ever changes.
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

### Deprecation (fixed)

Ruled by R 2026-10-20 (P11): the deprecation record below (`since`, `replacedBy`, `removeIn`, `note`) is used for engine schema and pack entries.

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
| GMs running episodes | The pack-update summary and the episode's settings screen list deprecations that affect the pinned pack |
| Players | Nothing; deprecation never changes play |

Packs use the same record for their own entries: see [02-rules-packs.md](02-rules-packs.md#deprecation-in-packs-fixed).

## Public API surface (Proposed)

```dart
/// Engine entry point for one episode.
final class Engine {
  Decision decide(EpisodeState state, Command command, Rng rng, IdSource ids);
  EpisodeState evolve(EpisodeState state, Event event);
}

sealed class Decision {}
final class Accepted extends Decision { final List<Event> events; }
final class Rejected extends Decision { final Rejection reason; }
```

The `RulesPack` is bound when the `Engine` is constructed, so `decide`/`evolve` cannot be called against the wrong pack.

## Testing

See [08-testing.md](08-testing.md#engine). Every system is tested as *given state, when command (with scripted dice), then events*, and every event as *given state, when event, then state*.
