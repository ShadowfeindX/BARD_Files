# Engine core

The engine (`packages/engine`) is the game: pure Dart, Dart SDK only, no I/O, no clock and no randomness it was not handed. Design: [01-engine.md](../architecture/01-engine.md). Everything public is exported from `package:engine/engine.dart`.

## The loop

```dart
final engine = Engine(pack);                       // pack bound once
final decision = engine.decide(state, command, rng, ids);
switch (decision) {
  case Accepted(:final events): state = engine.replay(state, events);
  case Rejected(:final reason): /* reply to the sender */
}
```

- `decide` is the only function that draws from the `Rng` or the `IdSource`. A rejection produces no events and draws nothing.
- `evolve` (and `replay`, a fold of it) never fails and never rolls. Every client runs it.
- Commands before `StartOperation` are rejected with `RejectionCode.notStarted`.
- An engine bound to a different pack than the operation pinned refuses every command (`RejectionCode.packMismatch`).

## Where things live

| Folder (`lib/src/`) | Holds |
|---|---|
| `commands/` | The sealed `Command` family. One `part` file per system, each with a sealed sub-family (`OperationCommand`, `CharacterCommand`). |
| `events/` | The sealed `Event` family, laid out the same way. Every event has an `actor` and a `visibility`. |
| `components/` | The sealed `Component` family and one `ComponentType` constant per component (`Identity.componentType`, ...). |
| `state/` | `OperationState` (meta, ECS stores, pending requests and checks, RNG draw count), `ComponentStores` and `PendingState`. |
| `checks/` | Value types of the check flow: ids, `Difficulty`, `CheckModifier`, `CheckSpec`, `CheckBreakdown`, `CheckOutcome`, `DrawRange`, `RollSourceKind`. |
| `read_models/` | `DerivedStats`: derived stats and the `VitalsView` (Health and Sanity now), computed from attributes, never stored. |
| `narrator/` | `Narrator`: plain-text log lines per event, with GM, player and redacted lines. |
| `systems/` | One class per system. Each decides its own command sub-family and applies its own event sub-family. |
| `expr/` | Dice expressions and formulas: nodes, evaluator with breakdown, JSON form, approved `var` keys. |
| `pack/` | `RulesPack`; `files/` holds one parser plus value types per pack file; `load/` holds `loadPack`, the issue log, the pending-D marker and the content hash. See [packs.md](packs.md). |

All state is immutable. `ImmutableMap` is copy-on-write; it can be swapped for a structurally shared map later without changing its API.

## Adding a command and its event

1. Add the command class to the system's `commands/<system>_commands.dart` part, extending that system's sealed sub-family.
2. Add the event class to `events/<system>_events.dart` the same way. Give it value equality (`==`, `hashCode`), like the others: tests and the replay check compare events and states by value.
3. Handle both in the system's `decide` and `evolve` switches. The compiler reports any missing case, so a new class cannot be forgotten.
4. A new system gets a new sealed sub-family in both families and one line in each switch in `engine.dart`.
5. Write *given events, when command (scripted dice), then events* tests (08 §Engine).

## Adding a component

Add the class to `components/components.dart` with a `static const componentType = ComponentType<X>._('x')` and register it in `componentTypes`. The `typeKey` never changes within an engine major. Components never store values that can be derived (Health max, Evasion, ...).

## Checks and consequences

```
Player:  RequestAction(entity, description, suggestedSkill?)  → ActionRequested   (GM + that player)
GM:      DeclineRequest(request, reason?)                      → RequestDeclined
GM:      RequireCheck(entity, attribute?, skill?, difficulty,  → CheckRequired     (pending until resolved)
                      modifiers, request?, visibility)
GM:      ResolveCheck(check)                                   → CheckResolved     (a RollingEvent)
GM:      ApplyDamage / ApplySanityLoss / ApplyCondition        → DamageApplied / SanityLost / ConditionApplied (Consequences)
GM:      ClearCondition                                        → ConditionCleared
```

- A check totals `primary die + attribute score + proficiency dice + modifiers` (§2, G16). At or above the DC is a success; short by at most the pack's `partialSuccessWithin` is a partial success; otherwise a failure. Fumbles (G1) and Luck advantage (G2) stay off until D rules. Assistance and opposed checks are not built yet.
- With `autoResolveChecks` on, `RequireCheck` emits `CheckRequired` and `CheckResolved` together.
- `CheckResolved` carries the whole `CheckBreakdown` (every face, explosions included), the DC, the outcome, its `DrawRange` and `source` (`rng`; `entered` is reserved, concern 7).
- `Consequence` marks the events the session holds for GM review (F2): today `DamageApplied`, `SanityLost` and `ConditionApplied`. F2 also covers "any category value"; no such event exists yet. `withAmount` (damage, sanity; refuses a negative amount) and `ConditionApplied.withCondition` give the edited event with the original in `overriddenFrom`. `CheckResolved` is never a consequence. Amounts are GM-entered for now; damage dice, DR and sanity bands come with the vitals rules.
- Check dice (the pack's primary die and tier bonuses) may not divide or read `var` values: a division by zero depends on the faces, so it could only fail after drawing. The one failure still possible after drawing is a total past `maxSafeInteger`, which real dice cannot reach; `Engine.decide` throws a `StateError` rather than return a rejection that drew.
- `CheckResolved.enteredBy` is reserved with `source` (concern 7: who entered physical faces) and is always `null`.
- `Vitals` stores losses (`damageTaken`, `sanityLost`), not current values, so maximums stay derived. `DerivedStats(pack).vitals(state, entity)` gives the current values, unclamped.
- `Narrator(pack).narrate(state, event)` returns a `Narration`. A GM review edit ("changed by the Handler from 4") is in the GM's line only; players read the final value. The session picks the line per audience from the event's visibility: GM always `gm`; players allowed by `Public` or `AliasesOnly` get `player`; with `Redacted` every player gets `redacted`; `GmOnly` has no player line.

## Expressions and formulas

Packs write data-only trees (P4); there is no scripting:

```json
{"type": "const", "value": 10}
{"type": "attr", "key": "END"}
{"type": "var", "key": "newScore"}
{"type": "dice", "count": 1, "sides": 6, "explode": true}
{"type": "sum", "terms": [ ... ]}
{"type": "keepHighest", "pool": [ ... ], "keep": 1}
{"type": "op", "op": "mul", "args": [ ... ]}
```

- `op` is one of `add sub mul div min max floor`. `sub` and `div` take two arguments, `floor` one, the rest one or more.
- `explode` may be `true`, `false`, `null` or left out. `null` or absent means "not ruled" (G3) and rolls like `false`: R's setup decision 1 (2026-10-21) keeps a feature off while its value is pending D, so only the primary d6, marked `true`, explodes.
- Every number must be finite and at most 2^53 - 1 in size (`maxSafeInteger`), in the pack and in every result, because larger ones differ between the VM and the web. `Attr` keys may not be empty and `Var` keys must be in `VarKeys.all`.
- `decodeExpr` refuses unknown keys, so authoring annotations must be stripped first. It also refuses any `var` key not passed in `allowedVars`; each approved key (`VarKeys`) belongs to one placement. A new key or placement goes to R first.
- `evaluate` returns a `Term` tree: the value plus every die face, so the UI shows the breakdown without recomputing. `evaluateFormula` refuses dice. Whole results and constants are always `int`, so encoded numbers are the same on the VM and the web.
- Nodes roll depth first, left to right; the same tree draws from the RNG in the same order every time.

## Randomness

- Tests use `ScriptedRng([faces...])`: it fails loudly when the script runs out or a face does not fit the die.
- Production uses `XoshiroRng` in `packages/session` (`xrandom` 0.7.2 `Xoshiro128pp`, pinned). One draw is one 32-bit output; dice use rejection sampling. Reopening an operation passes the stored draw count, and the generator skips to it.
- The known-seed vectors in `packages/session/test/xoshiro_rng_test.dart` come from the reference C implementation. The program is kept in the project's shared library folder (`probes/xoshiro128pp-vectors/`), not in this repository, since the stack is Dart only. CI runs the vectors and the engine tests on the VM and on Node.js (`dart test -p node`). Locally, `dart test -p chrome` also passes (as root, Chromium needs a wrapper that adds `--no-sandbox`).

## Invariants later work must keep

From the gate review of the engine core (2026-10-21):

- **RNG draw count.** Each rolling event (`RollingEvent`) records the range of draws it used, and `Engine.evolve` sets `RngState.drawCount` to the end of that range, in one place for every rolling event. It never adds to it. A rejected command leaves the count where it was: the check system validates everything (pending check, scores, tiers, the values its dice read, and that the RNG's count matches the state's, else `rngOutOfSync`) before its first draw. `Engine.decide` throws a `StateError` if a rejection drew anyway, since that would be a bug. Tests: `check_system_test.dart`, group "draw-count invariant".
- **Entity ids.** `SequentialIdSource` restarts at `start`. The production `IdSource` in the session must never hand out an id already in the log after a crash and reopen. It derives the next id from state, or stores its counter with the commit marker.

## Proposed in this code (for R to accept or change)

- The public API shape (01 §Public API surface is Proposed): `Engine`, `Decision` (`Accepted` / `Rejected`), `Rejection` and `RejectionCode`.
- Command, event and rejection names and fields; `OperationSystem` (01 lists no system for the operation lifecycle); `Visibility` as `Public` / `GmOnly` / `AliasesOnly` / `Redacted` (03 lists the four; the class names are Proposed); an agent's `AgentCreated` is seen by the GM and its owner.
- `EntityKind` values (from 01's entity list) on `Identity`; display and filtering only.
- The breakdown types (`Term` and its subclasses) that rolling events will carry.
- Setting defaults: auto-resolve and auto-confirm off.
- `KeepHighest` and its JSON form; `floor` as an `op`.
- `engineVersion` `1.0.0-dev.1`: major 1 matches `engineApi` 1, which the provisional pack declares (the scaffold had 0.0.0).
- Seeds stay in `session`, not in engine state: state keeps only `RngState.drawCount`, so nothing broadcast can carry the seed. `CheckResolved` is the first event that advances it.
- The check flow: command and event names and fields; `CheckSpec`, `CheckBreakdown`, `DrawRange`; `Difficulty` as a pack category or a fixed DC (the fixed form also covers Cat-Ω values the Handler sets, G12, and the book's old named DCs, G13); `rngOutOfSync`, `unknownRequest`, `unknownCheck` and `unavailable` rejection codes; a request is seen by the GM and the player who sent it.
- `maxEnteredValue` (2^31 - 1): the largest magnitude accepted for a number the GM types (a fixed DC, a modifier, a damage or sanity amount, a review edit), checked before any draw so every sum stays within the range the VM and the web agree on (gate review of row 5).
- A skill with no recorded tier on the entity adds no proficiency dice (the pack's `untrained` tier also has no bonus).
- GM-entered consequences with a `visibility` the GM chooses (default `Public`); `ConditionApplied` is a consequence, `ConditionCleared` is not (it is a direct GM edit). Players do not see that a value was edited in review, only the final value.
- The engine does not check that an alias owns the entity it acts for; authorization is the session's (04). Applying an active condition again, or clearing one that is not active, is rejected. A consequence's `check` id is recorded, not checked.
- `Vitals` stores losses rather than current values; `Conditions` holds only ids for now. `DerivedKeys.health` and `DerivedKeys.sanity` (`health`, `sanity`) are engine vocabulary the vitals view reads.
- The narrator's English wording and line shapes. 01 says narration uses the pack's `strings/`, which has no narration templates yet; moving the wording there is open.
- `SkillDef.category` and `SkillDef.attribute` are nullable because the provisional pack leaves some unset (G15).
- Not checked yet because the rule is not ruled: whether creation scores must total exactly 20 or at most 20, and whether the 3 Proficient + 1 Expert allotment is exact.
