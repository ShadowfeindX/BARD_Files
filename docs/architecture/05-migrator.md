# 05. Migrator (`packages/migrator`)

## Purpose (Fixed)

Move one operation's **state** and **pack** from engine major N to N+1. The GM runs it explicitly and reviews the result. Each engine major knows only its own schema and contains zero compatibility code across majors (compatibility decoding within a major is allowed; see [01-engine.md](01-engine.md#compatibility-decoding-within-a-major-fixed-allowed-additive-only)). There is no frozen prior engine and no old web build. Majors are rare (tied to reprinting the physical manuals).

## Why the migrator never imports the engine (Fixed, P8)

Ruled by R 2026-10-20 (P8): the migrator works on frozen JSON-level schemas, and each step is a pure `(json, decisions) -> (json, report)`.

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
| Event log of major N | **no** | frozen and archived as-is, with its text rendering (below) |

## Archived logs (Fixed: ruled by R)

R ruled archive-only: the N-major log is **frozen, not converted** into the N+1 schema. Converting would force the migrator to invent values for fields the old schema never recorded, and those placeholders would sit in history forever.

An archived operation keeps two files side by side:

| File | Contents | Read by |
|---|---|---|
| Frozen event log | The original N-major events, byte-for-byte, never decoded by the N+1 engine | Nobody in normal use; kept as the exact record |
| Text log | The plain-text rendering of every event as it appeared in the UI, stored per perspective (GM, public, redacted, specific aliases): the written description log the GM and players saw | The in-game log view and a separate archive viewer |

**How the text log is produced (Fixed, P12).** There is no frozen prior engine (Fixed), so the N+1 app cannot render N-major events. The text is therefore written **during play**, by the engine that understood the events: each time an event is applied, its display text is appended to the operation's text log with its `seq`, time and `visibility`. At migration the text log already exists and is archived unchanged. Each line stores one rendered variant per perspective (see `TextLogLine` in [04-session.md](04-session.md#interfaces-the-session-depends-on)), so the archive viewer shows a player exactly the text that player saw (including the redacted version of hidden events), and the GM everything.

```
seq=1042  2026-10-16T20:14:03Z  vis=public  <agent> requests an action: <description>.
seq=1043  2026-10-16T20:14:05Z  vis=public  Check resolved: <dice breakdown> = <total> vs DC <dc>. <outcome>.
seq=1044  2026-10-16T20:14:40Z  vis=gm      <GM-only note>.
```

(Placeholders only; real wording comes from the engine's event narrator and the pack's `strings/`.)

**After migration.** The N+1 operation starts a new log whose first event is the genesis event:

```
OperationMigrated(fromMajor: N, toMajor: N+1, archives: [ {major, opId, logRef, textLogRef}, ... ], migratorVersion, reportHash)
```

followed by the migrated snapshot as its initial state. The migrator transforms the **head snapshot** (the state at the N-major log's last `seq`, written by the N engine with every batch; see [04-session.md](04-session.md#the-operation-loop-gm-canonical-fixed)), so it never needs to fold events itself. Rolling autosave keeps the local head snapshot current after every batch and refreshes its RTDB copy before migration (P12). If the head snapshot is missing or its `seq` is not the log's last `seq`, the migrator refuses and nothing is written.

`archives` lists **every** earlier archive, oldest first: a second migration (N+1 → N+2) copies the N entry forward and adds N+1, so all pre-migration history stays reachable from the newest genesis event without opening any frozen log. (Fixed, P12: the N+1 operation gets a new operation id and restarts `seq` at 1; the archived operation keeps its id.) Every later event uses the N+1 schema. In the in-game log the archived text appears above the genesis event as a clearly marked read-only section; the archive viewer opens the same text on its own (placement and viewer fixed, P12).

**What is lost.** The N+1 engine cannot replay, query or inspect N-major events (for example re-opening a past roll's breakdown as structured data, or computing statistics across the boundary). Only the text and the migrated end-state carry forward. The frozen log is kept so nothing is destroyed, but it is not usable by the N+1 app.

## GM workflow

1. App detects that an operation's engine major is older than the installed engine. The operation opens read-only.
2. GM chooses "Migrate". The migrator runs locally on the GM device and produces: new snapshot, new pack, report.
3. The app shows the report: unchanged, transformed, dropped, and **needs decision** items (for example, a removed condition type with no successor). The GM resolves each decision item.
4. The new engine validates the result (loads the pack, folds the snapshot). Any failure aborts with nothing written.
5. **Explicit confirmation of information loss (Fixed: ruled by R; P13).** Before anything is written, the app shows a dedicated warning screen, separate from the report, that states plainly:
   - the operation's event history will be **frozen**; from now on it is viewable only as text;
   - past events can no longer be replayed, re-opened as structured data or used by the new engine;
   - anything the report lists as dropped is gone from the new operation;
   - **this cannot be undone or recovered.**

   The GM must take a deliberate action to proceed (Fixed, P13): tick "I understand this information cannot be recovered" and type the operation's name. A single tap never confirms it; a widget test covers this.
6. On confirmation the archive is written to Firestore and then the operation is locked. The archived operation (frozen event log, text log and final head snapshot) is written by the `archiveOperation` HTTPS function (FS3), chunked into a subcollection to stay under Firestore's 1 MiB per-document limit (FS5). After the archive write succeeds, the GM client sets the RTDB `meta/locked` flag. The new operation is then created. The original N data is kept until the GM deletes it.

Players do nothing. When they next join, they receive the new operation under N+1 and see a notice in the log that history before the migration is archived text (Proposed).

## Chaining

N → N+2 runs N → N+1 then N+1 → N+2. Each step is tested on its own. A step is a pure function `(json, decisions) → (json, report)`.

## Testing

Fixture pairs per step: realistic N snapshots and packs in, expected N+1 out. Archive tests: the frozen log is byte-identical after migration, the text log is carried over unchanged, the genesis event references both, a missing or stale head snapshot is refused with nothing written, and a two-hop migration (N → N+1 → N+2) keeps every archive in the genesis `archives` list. For the newest step only, an integration test checks that the output loads and folds in the current engine (which is N+1). That test is the one allowed `dev_dependencies` exception: `migrator` may depend on `engine` for tests only, never under `dependencies` (see [00-overview.md](00-overview.md#dependency-rules)). Library code in `migrator` stays Dart-SDK-only. See [08-testing.md](08-testing.md#migrator).
