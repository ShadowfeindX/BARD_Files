# 05. Migrator (`packages/migrator`)

## Purpose (Fixed)

Move one operation's **state** and **pack** from engine major N to N+1. The GM runs it explicitly and reviews the result. Each engine major knows only its own schema and contains zero compatibility code. There is no frozen prior engine and no old web build. Majors are rare (tied to reprinting the physical manuals).

## Why the migrator never imports the engine

A pub workspace resolves one version of each package for the whole repository, and Dart does not allow two versions of the same package in one resolution [V-1]. The migrator cannot import engine N and engine N+1 side by side. It works on **serialized JSON** instead:

```
packages/migrator/
  lib/src/schemas/v1/   frozen description of engine major 1's serialized shapes (plain Dart, JSON-level)
  lib/src/schemas/v2/   same for major 2
  lib/src/steps/v1_to_v2/
    state_step.dart     transforms an OperationState snapshot JSON
    pack_step.dart      transforms pack JSON (manifest engineApi bump, renamed keys, new required fields)
    report.dart         what changed, what could not be mapped, what needs a GM decision
```

When engine major N+1 is released, the engine's `schema/` docs for N and N+1 are copied into the migrator as frozen schemas. After that the migrator never changes for that step except to fix bugs.

## What gets migrated

| Item | Migrated? | How |
|---|---|---|
| Latest snapshot of the operation state | yes | `state_step` |
| Pinned pack (and any GM packs it requires) | yes | `pack_step` |
| Campaign-level data (aliases, settings) | yes | small dedicated steps |
| Event log of major N | **no** | archived read-only |

The N-major log is not rewritten, because history never changes (Fixed). It is archived with the operation and rendered as a read-only record (the text of what happened). The N+1 operation starts a new log whose first event is a genesis event:

```
OperationMigrated(fromMajor: N, toMajor: N+1, archivedLogRef, migratorVersion, reportHash)
```

followed by the migrated snapshot as its initial state.

## GM workflow

1. App detects that an operation's engine major is older than the installed engine. The operation opens read-only.
2. GM chooses "Migrate". The migrator runs locally on the GM device and produces: new snapshot, new pack, report.
3. The app shows the report: unchanged, transformed, dropped, and **needs decision** items (for example, a removed condition type with no successor). The GM resolves each decision item.
4. The new engine validates the result (loads the pack, folds the snapshot). Any failure aborts with nothing written.
5. GM confirms. The archive and the new operation are written together. The original N data is kept until the GM deletes it.

Players do nothing. When they next join, they receive the new operation under N+1.

## Chaining

N → N+2 runs N → N+1 then N+1 → N+2. Each step is tested on its own. A step is a pure function `(json, decisions) → (json, report)`.

## Testing

Fixture pairs per step: realistic N snapshots and packs in, expected N+1 out. For the newest step only, an integration test (in a test-only dev dependency on the current engine, which is N+1) checks that the output loads and folds. See [08-testing.md](08-testing.md#migrator).
