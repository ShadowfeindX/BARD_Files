# Rules packs: loading and validating

A pack is a folder of JSON files plus `manifest.json` (02 §Pack structure). The engine loads it with `loadPack`; the same code backs the app and the command-line validator, so "valid" means the same everywhere. The pack shape is Provisional, pending D. The provisional pack lives in `packages/content_core/assets/example-core/`.

## Check a pack from the command line

```bash
bash tool/build_pack.sh    # strips annotations into packages/content_core/assets/generated/example-core/
cd packages/engine && dart run engine:validate_pack ../content_core/assets/generated/example-core
```

Validate the generated pack, not the source: authoring annotations (`note`, `source`, `gap`, `_`-prefixed keys, ...) are unknown keys to the loader, and unknown keys are errors. The validator prints every error and warning with its file and JSON path, then a summary and, when the pack loads, its content hash. Exit code 1 means errors. The validator itself is Proposed (02).

## What the loader does

1. Accepts only known files: the top-level files in `packFiles` and one `.json` per entry in `items/`, `techniques/`, `npcs/`, `strings/`. A standalone pack needs `requiredPackFiles` (manifest, attributes, proficiency, skills, derived, difficulty).
2. Reads the manifest and refuses any `engineApi` other than the engine's. `requires` (packs on top of packs) is not supported yet and is an error.
3. Parses each file with its own parser, in `packages/engine/lib/src/pack/files/<file>.dart`, beside that file's value types. When D changes a file's shape, that one Dart file changes.
4. Checks cross-references: skill attributes and categories, formula attributes, the assistance gate category, damage categories used by ranges, items and threats, NPC threat classes, `replacedBy` targets, duplicate keys.
5. Computes the content hash and builds an immutable `RulesPack`.

Every problem is collected, so the author sees them all in one run.

## Pending D

`null` means "D has not ruled". It is a warning, never an error, and the pack lists every such place in `RulesPack.pendingPaths`, so a feature that needs one stays off and the UI can label it (setup decision 1). Two kinds:

- A **value** that may be pending: a skill's `attribute` or `category`, damage `dice` and `min`, a vehicle's `drivingModifier` or `hp`, `disorders.json` `rollDie`, an armor's `drModifier`, an NPC's `attributes`.
- A dice node whose `explode` is `null` or absent (G3), anywhere an expression appears. It rolls like `explode: false` until ruled, and its path ends in `.explode`.
- A **slot** that may only hold `null` for now, because the engine has no vocabulary for its value yet: for example `checkRules.fumble.basis` (G1), `luckAdvantage.grantedBy` (G2), `assistance.cap` (G4), advancement `effect` and `repeat` (G14). A real value there is an error until the engine supports it.

Two places use `null` as a real value, not the marker: a proficiency tier's `bonus: null` means "no bonus die", and an open-ended sanity-event row (`openEnded: true`) may have `max: null` because it has no top. Neither is listed in `pendingPaths`.

Every number in every file, including `occult.json`, must be finite and at most 2^53 - 1 in size; anything else is an error, because the VM and the web would read it differently and the content hash would differ.

`occult.json` is pending D as a whole (C5/G6, F3): it is kept as raw JSON in `RulesPack.occultPending`, not validated, and not used.

Which JSON value counts as the marker is decided in one function, `isPendingMarker` in `lib/src/pack/load/pending.dart`: `null`. R ruled (2026-10-21) that the annotation stripper turns marker objects into `null` and treats `_`-prefixed keys as annotations, so the generated pack carries `null` at every pending place. The engine's tests load that generated pack (`test/support/provisional_pack.dart`), so they need `bash tool/build_pack.sh` first; `tool/check_all.sh` and CI do this.

## Text fields of the provisional shape

Some provisional files carry explanatory text with no effect on rules (`decided`, `attributeSource`, `notShownHere`, `storedModifiersAllowed`, `appliesTo`). The parsers accept these as text and ignore them. They are listed in the parsers (`prose(...)` calls), so they go away with one edit each when D's pack shape replaces the provisional one. The old `*Placeholder` wrapper keys are now `_`-prefixed annotations (R, 2026-10-21) and are stripped before the loader sees the pack.

## Deprecation (P11)

Any entry may carry a `deprecated` record (`since`, `removeIn`, `note`, optional `replacedBy`), and any entry a `deprecatedFields` map of field name to record. A valid record loads with a warning. A malformed one is an error: `removeIn` must be a later major than the pack's own version, an entry's `replacedBy` of the form `kind:id` must name an existing entry (kinds: `attribute`, `skill`, `condition`, `item`, `technique`, `npc`), and a field's `replacedBy` must name another field of the same entry.

Engine-side deprecations of pack keys (a key the engine still reads but plans to drop) will also be warnings. There are none yet, so that path has no code until the first one; `lib/src/deprecation.dart` holds the record type both will share.

## Proposed shorthand

An advancement cost's `xp` may be a plain number instead of an expression; it is read as `{"type": "const", "value": n}`. This shorthand is Proposed (not in the spec) and goes to R with the row 4 PR.

## Content hash

`computeContentHash` covers every file in path order, each in canonical JSON (keys sorted, whole numbers as integers, no whitespace), so reformatting does not change it. The manifest's own `contentHash` is left out; if the manifest has one, it must match. The result is `sha256:<hex>` (Proposed format). SHA-256 is written in the engine (`sha256.dart`) because the engine imports only the Dart SDK; standard test vectors run on the VM and Node.js.
