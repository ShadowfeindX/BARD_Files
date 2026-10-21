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

## Where things live

| Folder (`lib/src/`) | Holds |
|---|---|
| `commands/` | The sealed `Command` family. One `part` file per system, each with a sealed sub-family (`OperationCommand`, `CharacterCommand`). |
| `events/` | The sealed `Event` family, laid out the same way. Every event has an `actor` and a `visibility`. |
| `components/` | The sealed `Component` family and one `ComponentType` constant per component (`Identity.componentType`, ...). |
| `state/` | `OperationState` (meta, ECS stores, RNG draw count) and `ComponentStores`. |
| `systems/` | One class per system. Each decides its own command sub-family and applies its own event sub-family. |
| `expr/` | Dice expressions and formulas: nodes, evaluator with breakdown, JSON form, approved `var` keys. |
| `pack/` | `RulesPack`, the in-memory pack. The loader that reads pack files comes with the pack loader work. |

All state is immutable. `ImmutableMap` is copy-on-write; it can be swapped for a structurally shared map later without changing its API.

## Adding a command and its event

1. Add the command class to the system's `commands/<system>_commands.dart` part, extending that system's sealed sub-family.
2. Add the event class to `events/<system>_events.dart` the same way. Give it value equality (`==`, `hashCode`), like the others: tests and the replay check compare events and states by value.
3. Handle both in the system's `decide` and `evolve` switches. The compiler reports any missing case, so a new class cannot be forgotten.
4. A new system gets a new sealed sub-family in both families and one line in each switch in `engine.dart`.
5. Write *given events, when command (scripted dice), then events* tests (08 §Engine).

## Adding a component

Add the class to `components/components.dart` with a `static const componentType = ComponentType<X>._('x')` and register it in `componentTypes`. The `typeKey` never changes within an engine major. Components never store values that can be derived (Health max, Evasion, ...).

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

## Proposed in this code (for R to accept or change)

- The public API shape (01 §Public API surface is Proposed): `Engine`, `Decision` (`Accepted` / `Rejected`), `Rejection` and `RejectionCode`.
- Command, event and rejection names and fields; `OperationSystem` (01 lists no system for the operation lifecycle); `Visibility` as `Public` / `GmOnly` / `AliasesOnly`; an agent's `AgentCreated` is seen by the GM and its owner.
- `EntityKind` values (from 01's entity list) on `Identity`; display and filtering only.
- The breakdown types (`Term` and its subclasses) that rolling events will carry.
- Setting defaults: auto-resolve and auto-confirm off.
- `KeepHighest` and its JSON form; `floor` as an `op`.
- `engineVersion` `1.0.0-dev.1`: major 1 matches `engineApi` 1, which the provisional pack declares (the scaffold had 0.0.0).
- Seeds stay in `session`, not in engine state: state keeps only `RngState.drawCount`, so nothing broadcast can carry the seed. No event advances it yet; rolling events (the check system) will.
- `SkillDef.category` and `SkillDef.attribute` are nullable because the provisional pack leaves some unset (G15).
- Not checked yet because the rule is not ruled: whether creation scores must total exactly 20 or at most 20, and whether the 3 Proficient + 1 Expert allotment is exact.
