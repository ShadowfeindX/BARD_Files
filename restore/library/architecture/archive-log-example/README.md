# Archived operation log: example, engine schema 1 vs schema 2

**Illustrative only.** Every game term, number and name here is a placeholder. The schema change from major 1 to major 2 is invented to exercise the migrator. D owns real content. Event names and fields follow [01-engine.md](../../../docs/architecture/01-engine.md) and [03-protocol.md](../../../docs/architecture/03-protocol.md) on branch `docs/architecture` (PR #2); anything not defined there is marked below as invented.

## Files

| File | What it is |
|---|---|
| `schema-1.log.jsonl` | The GM-side log of a tiny operation as written by engine major 1. One event per line, as stored. 12 events. |
| `schema-2.log.jsonl` | The same history after the proposed "migrator also converts logs" step. 13 events (genesis + 12). |
| `migration-report.json` | What the migrator would show the GM: transformed, unchanged, needs decision. |

Both logs are the GM's full copy, so hidden (`gm`) events are present. A player's cached copy would hold only what their perspective may see.

## What the example shows

Invented 1 → 2 changes, each a pattern the migrator will meet:

| # | Change in engine 2 | Kind | Lossless? |
|---|---|---|---|
| 1 | `CheckResolved.mods[{src:"attr:END",v}]` becomes `modifiers[{source:{kind,key},value}]` | rename + restructure | yes |
| 2 | `CheckResolved.draws:[a,b]` becomes `rng:{start,end}` | rename | yes |
| 3 | `outcome:"success"` (check and override) becomes `outcome:{band,margin}` | restructure + derived field | yes (`margin = total − dc`, taken from the event itself; `null` on overrides) |
| 4 | New `CheckResolved.advantage.extraDice` | added field, derivable | yes (count of `role:"luck"` dice already in the event) |
| 5 | `DamageApplied` and `SanityLost` merge into `VitalsChanged{vital,delta,cause}` | type merge (1:1) | yes |
| 6 | `ConditionApplied.duration:3` becomes `{unit:"rounds",n:3}` | restructure | yes |
| 7 | New **required** `ConditionApplied.source` that engine 1 never recorded | added field, **not derivable** | no: filled with `{kind:"unknown"}`, flagged as a GM decision |

Unchanged payloads: `EntitySpawned`, `ActionRequested`, `CheckRequired`, `PhoneMessageSent`.

## What the migrator did to the log

- Prepended a genesis event, `OperationMigrated` (seq 1), as [05-migrator.md](../../../docs/architecture/05-migrator.md) specifies. It holds the archive reference, the SHA-256 of the schema-1 file, and the report hash. The pack ref is the migrated pack's.
- Re-numbered every event (`seq + 1`), because the new log's seq starts at 1 with the genesis.
- Stamped every event with `e: "2.0.0"` and an `origin {major, seq, e}` pointing at the schema-1 event it came from. Original `e` values (1.0.0 to 1.3.0) survive only in `origin`.
- Kept resolved values exactly: dice faces, totals, DCs, RNG draw ranges, visibility, actors, ids. No roll was re-run and no pack formula was re-evaluated.
- Left the schema-1 file untouched as the archive.

## Things R should weigh when ruling

1. **This changes the written spec.** [05-migrator.md](../../../docs/architecture/05-migrator.md) currently says the N log is *not* migrated, only archived read-only and rendered as text, and the new log starts at the genesis event plus a migrated *snapshot*. This example is the other approach: convert the log. Under the current spec, the N+1 log would hold just `OperationMigrated` and a snapshot, and the history would remain readable only through archive tooling.
2. **Not every change is lossless.** Changes 1 to 6 are mechanical. Change 7 shows the real cost: when a major adds a required field, old events cannot supply it, so the log gets a placeholder and the GM must (optionally) fill it. Reads of "unknown" must stay supported in engine 2 forever, which is a small compatibility surface inside the engine, in tension with "zero compat code".
3. **Many-to-one and one-to-many changes.** All steps here map one event to one event. A major that splits or merges events would change the seq mapping; `origin` would then need a list. Not shown.
4. **The migrator must carry schema 1's event types** (frozen JSON shapes, no rules logic), and so grows by one event schema per major. Chaining N → N+2 runs the log through both steps, each tested on fixtures like these two files.
5. **Seeds and audit.** `rng {start,end}` still points into the original draw sequence, but the engine-2 PRNG may differ, so the seed can only audit schema-1 draws with the schema-1 algorithm. The seed itself is GM-only and is not in these files (`rngSeedRef` only).
6. **Cost of the alternative.** Without log conversion, the app keeps a read-only archive viewer that understands schema 1, or only renders the archived text. That is the trade the spec made.

## Invented for this example (not in the spec)

`origin`, `vis` as a field name, the `modifiers`/`source`/`outcome` shapes, `VitalsChanged`, `OperationMigrated`'s extra fields (`packMigratedFrom`, `archivedLogHash`), JSONL as the on-disk form, and every id. The spec defines the event *names* and the genesis event's field list only.
