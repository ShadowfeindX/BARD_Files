# Engine and Rules Pack Pinning (draft v1)

## 1. Three layers, three version numbers

| Layer | What it is | Version | Affects play outcomes? |
|---|---|---|---|
| **Engine** | Pure-Dart package. The interpreter: dice evaluation, check resolution, effect application, command → event processing, pack loading. | `engine X.Y.Z` (semver). Its **major** is the pack schema version. | Yes, through how it computes. |
| **Rules pack** | Data only. Numbers and composition expressed in the engine's vocabulary: dice counts, DCs, stat blocks, skills, level-up options, items, bestiary, tables, and later Typst form templates. | `pack X.Y.Z`, plus `requires: engine >= N.M` | Yes, through what it says. |
| **App shell** | Flutter UI, backend features, sync, accounts, payments. | App build version. | Never. |

The app shell can ship any time. Shipping it never changes how an operation plays.

## 2. The core rule: vocabulary vs values

- The **engine owns vocabulary**: what *kinds* of things exist and how each kind is computed. For example, a check, a dice expression, a modifier, a condition, damage, sanity loss, and an effect trigger.
- The **pack owns values**: which instances exist and their numbers. For example, "Lockpicking uses DEX", "a shotgun deals 3d6", or "level 3 grants +1 to one attribute".

Two test questions decide where a change goes:
1. *Can this be written by editing pack data with vocabulary the engine already has?* If yes, it's a **pack change**.
2. *Does it need a new kind of thing, or a different way of computing an existing kind?* If yes, it's an **engine change**.

## 3. Engine change classes

| Class | Definition | Ships to | Pinned operations | Pack impact |
|---|---|---|---|---|
| **Patch** `X.Y.Z+1` | The engine doesn't do what its own spec says: a biased RNG, a modifier applied twice, a crash. | Everyone, in app updates. Web gets it immediately. | **Affected.** Pinning holds the pack, not the engine. This is the caveat. | None. Correct packs keep their meaning. |
| **Minor** `X.Y+1.0` | New vocabulary added without changing existing vocabulary, such as a new effect type or dice notation. | App updates. | Unaffected. Old packs never use the new vocabulary. | New packs that use it declare `engine >= X.Y+1`. Older clients refuse to download them. |
| **Major** `X+1.0.0` | Changes the meaning or schema of existing vocabulary: a structural change. | App updates. | Must be migrated before continuing. See section 7. | New-major packs are undownloadable by older clients. That's R's cutoff rule. |

## 4. Pack change classes

| Class | Definition | Examples | Pinned operations |
|---|---|---|---|
| **Patch** `x.y.z+1` | Errata: the pack doesn't match the rulebook, such as a transcription error or a wrong stat copied in. | A weapon damage typo, a missing skill. | Not applied by default. The GM applies it, or turns on automatic pack updates (see section 8). |
| **Minor** `x.y+1.0` | Balancing: the rules themselves changed, with the same vocabulary. | 2d6 becomes 3d6, a new stat block, level-up gives +3 instead of +1. | Not applied. The GM can choose to upgrade an operation. |
| **Major** `x+1.0.0` | Restructured content that's incompatible with saved state, such as removed or renamed skills that existing aliases reference. | A rework of the skill list. | Not applied. Upgrading needs a migration step. |

## 5. Grey areas, resolved

- **"The dice bug":** if the engine computes 2d6 incorrectly, that's an engine patch, and it applies everywhere. If the rulebook changes from 2d6 to 3d6, that's a pack minor, and pinned operations keep 2d6.
- **Wrong number in the pack:** the engine is fine, so this is a pack patch, never an engine fix.
- **The rulebook adds a mechanic the engine can't express,** such as a new resource type: this is an engine minor first, then a pack minor that requires it.
- **History never changes.** The event log stores *resolved results* (the actual dice values and outcomes), not inputs to re-simulate. An engine patch changes future rolls only. Past events and GM overrides stay as recorded.
- **Modified packs (GM or player forks)** get a local pack id, pin the same way, and are checked against the same `requires: engine` constraint.

## 6. What an operation records

`pack id + exact pack version + pack schema major + engine version last used`.

When an operation opens: the pack version must be cached locally (offline-first), and the engine must support that schema major. Otherwise the client says exactly what's missing.

## 7. Cost of engine majors

Decided by R on 2026-10-16: **migrator only.** Each engine major knows only its own schema and contains no backward or cross-major compatibility code. A separate **migrator package** transforms an operation's state and rules pack from major N to N+1. The GM runs it explicitly and reviews the result. No frozen prior engine is bundled in the app, and no old web build is kept online.

Consequence: when an engine major ships, an in-flight operation must be migrated before it continues on the new engine. This is acceptable because majors are rare: they coincide with reprinting the physical manuals.

## 8. Decisions for R

1. **Update defaults:** decided. Engine updates apply automatically by default. Pack updates, including errata patches, are manual by default. The GM gets a UI toggle for each.
2. **Compatibility across engine majors:** decided on 2026-10-16. Migrator only, as described in section 7. No load-time migration or legacy systems inside the engine, and no bundled engine versions.
3. **Seeded RNG:** decided. The GM's engine uses a seeded, logged RNG, so any roll can be audited or replayed. It also makes engine tests deterministic.
