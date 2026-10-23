# 02. Rules packs and content

## Vocabulary vs values (Fixed)

| Owned by the engine (vocabulary) | Owned by a pack (values) |
|---|---|
| "An attribute is a named integer score on an entity" | The nine attributes STR, DEX, END, PER, INT, WIS, CHA, WIL, LCK and their descriptions (§3) |
| "A proficiency tier adds a bonus expression to checks" | The tiers and their bonuses |
| "A difficulty category maps to a DC" | Cat-F 3 … Cat-S 21 … (§2) |
| "A derived stat is a formula over attributes" | Health, Sanity, Evasion, Initiative formulas (§3) |
| "A weapon has a damage category" | The damage table (§6) |
| "A threat class is a stat template" | Human and supernatural threat tables (§10) |
| "An item/technique/NPC is an entity template" | D's items, techniques, NPCs; GM-made content |

If a new rule needs a new *kind* of thing, that is an engine change. If it needs a new *number, name or row*, that is a pack change. The app shell can do neither.

## Pack structure

**Format (Fixed, P3).** A pack is a folder of JSON files plus a manifest, not YAML. The Dart SDK reads JSON with no extra dependency and every editor understands it. UI editing of packs is planned, since GMs publish packs too. Ruled by R 2026-10-20 (P3).

**Pack shape: confirmed by D (2026-10-22, [09-open-decisions.md](09-open-decisions.md#decisions-record-ruled-by-d-2026-10-22)).** The file list below stays; files and fields added by D's other rulings (creation profiles, combat defaults, assistance) are additive. The example pack for D lives in the project library, not in this repository.

```
core/                           pack id
  manifest.json                 id, name, version, engineApi, publisher, requires[], contentHash
  attributes.json
  proficiency.json
  difficulty.json
  derived.json                  formulas (data-only expression trees)
  skills.json                   skills: name, description, category, attribute, proficiency (§5)
  conditions.json               condition/affliction templates (§4)
  disorders.json                disorder table (§4)
  sanity_events.json            sanity loss table (§4)
  damage.json                   damage categories (§6)
  vehicles.json                 performance and durability categories (§6)
  ranges.json                   range bands and penalties (§7)
  occult.json                   magic categories, sanity costs (§8; provisional, pending D)
  advancement.json              XP costs (§9)
  threats.json                  threat classes (§10)
  items/                        one file per item template
  techniques/
  npcs/
  strings/                      display text, so wording can change without touching rules
```

### Manifest (example values)

```json
{
  "id": "core",
  "name": "B.A.R.D. Files Core",
  "version": "1.3.1",
  "engineApi": 1,
  "publisher": "bard-official",
  "requires": [],
  "verification": "verified"
}
```

- `engineApi` is the engine major the pack targets (Fixed). The engine refuses to load a pack with a different major.
- `version` is the pack's own semver. Pack minor/patch bumps are value changes; a pack major means values changed incompatibly (for example a key was renamed).
- `requires` lets a GM pack extend another pack (for example a campaign pack on top of `core`). Resolution is by id + version range; conflicts are a load error, never a silent override.
- `contentHash` is computed by tooling, not written by hand, and is what an operation pins.

### Skills (Fixed, F3 part 2)

A skill is: `name`, `description`, `category`, `attribute`, `proficiency`. There are five categories; they are organizational only and have no mechanical effect. `skills.json` has no "allowed uses" list (dropped; ruled by R 2026-10-20, F3). D ruled on 2026-10-22 that "cast magic" is one roll kind with a Handler-set DC ([09-open-decisions.md](09-open-decisions.md#decisions-record-ruled-by-d-2026-10-22)).

### Named variables in pack formulas (Fixed)

Pack formulas and dice expressions are data-only trees (P4). Besides the existing nodes they may use a variable node:

```json
{ "type": "var", "key": "newScore" }
```

It is a named number supplied by the engine at evaluation time. Approved placements (ruled by R 2026-10-20):

| Placement | Expression |
|---|---|
| Advancement: attribute purchase XP, in `advancement.json` | 10 × `var(newScore)` |
| Assistance bonus, in `difficulty.json` | 1d6 + `var(helperSkillBonus)` |

The node itself is defined in [01-engine.md](01-engine.md); no other placement exists until R approves one.

### Authoring annotations (Fixed)

While authoring, pack files may carry annotation keys (`note`, `source`, `openItems`, `placeholder`, `gap`, `*Note` keys, and any key starting with `_`; R, 2026-10-21). Tooling strips them before a pack ships. An object that held only annotations becomes `null`, the single pending-D signal. There is no reserved annotation key in the schema, so the validator's rule that an unknown key is an error stands for every shipped pack.

### Deprecation in packs (fixed)

Ruled by R 2026-10-20 (P11). Packs use the deprecation record defined in [01-engine.md](01-engine.md#deprecation-fixed) for three things. In a pack's own records, `since` and `removeIn` are **pack** versions, since packs version independently of the engine.

1. **Engine-deprecated keys.** When the engine deprecates a pack key (for example a field of `skills.json`), packs that still use it load normally and the validator reports a warning naming the replacement and the engine major that removes it.
2. **Pack-deprecated entries.** A pack author marks one of their own entries as going away:

   ```json
   {
     "id": "example_old_skill",
     "deprecated": {
       "since": "1.5.0",
       "replacedBy": "skill:example_new_skill",
       "removeIn": 2,
       "note": "Illustrative placeholder, not a real rules change."
     }
   }
   ```

   Here `since` 1.5.0 and `removeIn` 2 refer to the pack's version. Within a pack major the entry keeps working; removing it is a pack major bump. GMs see the warning in the pack-update summary before they choose to apply the update.
3. **Pack-deprecated fields.** A pack author can deprecate a single field on one of their own objects with an optional `deprecatedFields` map, keyed by field name, using the same record:

   ```json
   {
     "id": "example_item",
     "oldField": 3,
     "newField": 3,
     "deprecatedFields": {
       "oldField": {
         "since": "1.6.0",
         "replacedBy": "newField",
         "removeIn": 2,
         "note": "Illustrative placeholder, not a real rules change."
       }
     }
   }
   ```

   Only fields the engine allows the pack to define can be deprecated this way. The validator warns on each, exactly as for entries.

## Loading and validation

1. Read manifest, check `engineApi`.
2. Resolve `requires`.
3. Parse every file into engine value types. Unknown keys are errors, not warnings, so typos in D's edits surface immediately.
4. Cross-validate references (a skill that names an attribute that does not exist, an item referencing an unknown damage category).
5. Produce an immutable `RulesPack` and its `contentHash`.

The validator is part of the engine package so the apps and a command-line tool all agree on what "valid" means. A small command-line validator in the engine package (Proposed) lets D check a pack without running the app.

Backend code (Cloud Functions) does not run the validator (it never imports the engine; see [00-overview.md](00-overview.md#dependency-rules)). Publishing validates on the publishing device before upload, and every device validates again when it loads a pack, so an invalid upload can never be used. Library verification is a human review step, not a server-side check.

## Operations pin packs

- An operation records `packRef = (id, version, contentHash)` in its meta when created.
- **Pack updates are manual by default (Fixed).** When a newer pack version exists the GM sees it, with a summary of what changed, and chooses when to apply. Applying records a `PackUpdated(from, to)` event, so the log shows exactly when values changed.
- **Engine updates are automatic by default (Fixed)** within a major. The GM toggles for both live in operation settings and are stored in operation meta.
- Because events carry resolved results, a pack update never changes past outcomes.

## Content kinds and tiers

| Tier | Who creates | Where it lives | Shown in public library |
|---|---|---|---|
| Core | D (official) | cloud-hosted, bundled copy in apps | yes |
| Library | any GM, submitted for review | cloud-hosted | only once verified |
| Campaign / private | a GM | the GM's account (and local cache) | no |
| Operation-scoped | a GM, for one session | pinned to that operation | no |

- The **operation-scoped tier** (Fixed, F3 part 3) sits under Campaign and holds per-session GM content. It uses the same schema and the same validator as any pack, is pinned by the operation (`packRef`), and its use is logged like any other pack change.
- GMs create NPCs, items, skills and techniques as entity templates in their own pack(s). These are ordinary pack files, so they use the same validator.
- The **public library** is a government-style archive showing only items with `verification: verified` (Fixed).
- **Who verifies (Fixed, concern 5).** At first only R and D hold the verification claim. It is set by the roles function; more auditors can be added later via the console.
- **Revocable.** Verification can be revoked: the item goes back to pending, with a reason. Copies already in GMs' packs are unchanged.
- **Record.** Each library item records the verifier, the date and the version verified.
- **Where it lives.** The library lives in Firestore (FS1). Verification is written by the reviewer's client under Firestore rules, never by the submitting client (B3, FS1); a function can take it over later if the rules get awkward. See [06-accounts-backend.md](06-accounts-backend.md).
- Library items are copied into a GM's pack when used, with provenance (for example `libraryRef: library/<id>@<version>`; the field name is provisional with the pack shape and must not reuse the stripped `source` annotation key), so a library edit never changes a running campaign behind the GM's back.

## Distribution

- The core pack ships inside the apps (offline first) and is also published to the backend so newer versions can be fetched.
- Pack files live in Cloud Storage and the pack index lives in Firestore (FS1). Pack files are immutable per version; a new version is a new upload.
- The local cache stores every pack version an operation references, so an offline device can always open its operations.

## Documents (Typst, later)

R plans document templating with Typst later: documents stored as text and rebuilt on clients as PDFs. No strict templates now. The architecture leaves a seam: a `DocumentSource` (text + data bindings) stored as pack or campaign content, and a `DocumentRenderer` interface in the app layer. No engine involvement. Choosing how Typst is invoked on each platform is future work for R.
