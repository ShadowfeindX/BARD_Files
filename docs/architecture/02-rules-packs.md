# 02. Rules packs and content

## Vocabulary vs values

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

**Format.** A pack is a folder of JSON files plus a manifest. The Dart SDK reads JSON with no extra dependency and every editor understands it. UI editing of packs is planned, since GMs publish packs too.

**Pack shape.** The file list below is the layout; files and fields added for creation profiles, combat defaults and assistance are additive. The example pack for D lives in the project library, not in this repository.

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
  combat.json                   Proposed: actions per turn
  occult.json                   magic categories, sanity costs (§8; "cast magic" is one roll with a Handler-set DC)
  advancement.json              XP costs (§9)
  threats.json                  threat classes (§10)
  items/                        one file per item template
  techniques/
  npcs/
  tables/                       random tables, one per file: id, name, dice, optional lead, rows {from, to, text}
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

- `engineApi` is the engine major the pack targets. The engine refuses to load a pack with a different major.
- `version` is the pack's own semver. Pack minor/patch bumps are value changes; a pack major means values changed incompatibly (for example a key was renamed).
- `requires` lets a GM pack extend another pack (for example a campaign pack on top of `core`). Resolution is by id + version range; conflicts are a load error, never a silent override.
- `contentHash` is computed by tooling, not written by hand, and is what an episode pins.

### Skills

A skill is: `name`, `description`, `category`, `attribute`, `proficiency`. There are five categories; they are organizational only and have no mechanical effect. `skills.json` has no "allowed uses" list. "Cast magic" is one roll kind with a Handler-set DC.

### Pack-side values by file

What the game rules mean for each pack file. Field names and shapes marked Proposed are not final. A value D has not given stays `null` in the pack and the feature stays off (CLAUDE.md §9). The engine side of each item is in [01](01-engine.md#rulebook-values-the-engine-uses).

| File | Content | Shape |
|---|---|---|
| `skills.json` | Mind Shielding stays (WIL); Eldritch Lore (INT) and Vehicle Modification (INT) are added; Insight uses WIS; the paired skills (Alchemy and Advanced Alchemy, Explosive Disposal and Explosives) stay separate; categories come from the book's skill list, never reconstructed | data only |
| `occult.json` | The cast attribute is WIL, or the named skill's attribute; `sanityCheckOn` defaults to success and `sanityPayers` is present on success, participants on fail; `ritualDefaults` is Handler guidance only; the `artifact` key holds the book's rule (+1d6, +2 Sanity per category above D) and `focusItem` is `null` until its reduction is given (open: FE-M5 in [10](10-waiting-on-d.md)) | `chosenAttribute: "skill"` with `fallback: "WIL"`, `sanityPayers`: Proposed |
| `difficulty.json` | `checkRules.fumble` is the total, rounded down; `assistance.cap` is the roll attribute's score plus 1 and `assistance.bonus` is the helper's own score in that attribute; `luckAdvantage` stays pending and unused (flashback covers its role); difficulties are stated as categories only | `basis: "total"`, `rounding: "down"`, `{"type": "attributePlus", "plus": 1}`: Proposed |
| `sanity_events.json`, `disorders.json` | Ranges are suggestions the Handler may override; the resist DC follows the Sanity band (20, 40, 60, 80, 100% for Cat-S to Cat-D); half loss rounds down; fumbled resist costs the full loss plus 1; a failed disorder check rolls 1d6. The reworked tables are open ([10](10-waiting-on-d.md), FD-S2) | `pick: "gm"`, `resistDc.bands`, `halfRounding`, `fumbleExtra`, `rollDie`: Proposed |
| `damage.json`, `threats.json` | Damage dice explode; `min` is a floor on the total damage, and a melee weapon's floor is the greater of its MIN and the STR score. Weapon MIN values stay `null` until they are given | `meleeFloor`: Proposed |
| `proficiency.json`, `advancement.json` | Proficiency and advancement dice do not explode | `explode: false`, data only |
| `attributes.json`, `proficiency.json` (creation) | Creation limits by character kind: `agent` (also Occult Organization members) and `skald` | profile names and fields: Proposed |
| `combat.json` | One Major, one Minor and one reaction per turn by default | `actionsPerTurn`: Proposed |
| `tables/` | Random tables are a generic kind; the engine ships no rows, the table content is D's | as in the structure above |
| `npcs/`, `threats.json` | Human adversaries use attributes, skills and `items/` like a player alias; class numbers apply to supernatural classes only | note for when the enemy defense and attack numbers are given |

Rounding: wherever a pack states a fraction, it states the rounding direction beside it, and the direction favours the player.

Still `null` (deferred): armor and damage reduction, enemy defense and attack, advancement purchase limits, currency. They are listed in [10-waiting-on-d.md](10-waiting-on-d.md).

### Named variables in pack formulas

Pack formulas and dice expressions are data-only trees. Besides the existing nodes they may use a variable node:

```json
{ "type": "var", "key": "newScore" }
```

It is a named number supplied by the engine at evaluation time. Placements:

| Placement | Expression |
|---|---|
| Advancement: attribute purchase XP, in `advancement.json` | 10 × `var(newScore)` |
| Assistance bonus, in `difficulty.json` | the helper's attribute score (key name Proposed) |

The node itself is defined in [01-engine.md](01-engine.md); no other placement exists until R approves one.

### Authoring annotations

While authoring, pack files may carry annotation keys (`note`, `source`, `openItems`, `placeholder`, `gap`, `*Note` keys, and any key starting with `_`). Tooling strips them before a pack ships. An object that held only annotations becomes `null`, the single pending-D signal. There is no reserved annotation key in the schema, so the validator's rule that an unknown key is an error stands for every shipped pack.

### Deprecation in packs

Packs use the deprecation record defined in [01-engine.md](01-engine.md#deprecation) for three things. In a pack's own records, `since` and `removeIn` are **pack** versions, since packs version independently of the engine.

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

## Episodes pin packs

- The pack version pin lives at the **campaign** so characters' numbers do not change between missions; the episode-scoped pack tier stays below it. An episode records `packRef = (id, version, contentHash)` in its meta when created.
- **Pack updates are manual by default.** When a newer pack version exists the GM sees it, with a summary of what changed, and chooses when to apply. Applying records a `PackUpdated(from, to)` event, so the log shows exactly when values changed.
- **Engine updates are automatic by default** within a major. The GM toggles for both live in episode settings and are stored in episode meta.
- Because events carry resolved results, a pack update never changes past outcomes.

## Content kinds and tiers

| Tier | Who creates | Where it lives | Shown in public library |
|---|---|---|---|
| Core | D (official) | cloud-hosted, bundled copy in apps | yes |
| Library | any GM, submitted for review | cloud-hosted | only once verified |
| Campaign / private | a GM | the GM's account (and local cache) | no |
| Episode-scoped | a GM, for one episode | pinned to that episode | no |

- The **episode-scoped tier** sits under Campaign and holds per-episode GM content. It uses the same schema and the same validator as any pack, is pinned by the episode (`packRef`), and its use is logged like any other pack change.
- GMs create NPCs, items, skills and techniques as entity templates in their own pack(s). These are ordinary pack files, so they use the same validator.
- The **public library** is a government-style archive showing only items with `verification: verified`.
- **Who verifies.** At first only R and D hold the verification claim. It is set by the roles function; more auditors can be added later via the console.
- **Revocable.** Verification can be revoked: the item goes back to pending, with a reason. Copies already in GMs' packs are unchanged.
- **Record.** Each library item records the verifier, the date and the version verified.
- **Where it lives.** The library lives in Firestore. Verification is written by the reviewer's client under Firestore rules, never by the submitting client; a function can take it over later if the rules get awkward. See [06-accounts-backend.md](06-accounts-backend.md).
- Library items are copied into a GM's pack when used, with provenance (for example `libraryRef: library/<id>@<version>`; the field name is provisional with the pack shape and must not reuse the stripped `source` annotation key), so a library edit never changes a running campaign behind the GM's back.

## Distribution

- The core pack ships inside the apps (offline first) and is also published to the backend so newer versions can be fetched.
- Pack files live in Cloud Storage and the pack index lives in Firestore. Pack files are immutable per version; a new version is a new upload.
- The local cache stores every pack version an episode references, so an offline device can always open its episodes.

## Documents (Typst, later)

R plans document templating with Typst later: documents stored as text and rebuilt on clients as PDFs. No strict templates now. The architecture leaves a seam: a `DocumentSource` (text + data bindings) stored as pack or campaign content, and a `DocumentRenderer` interface in the app layer. No engine involvement. Choosing how Typst is invoked on each platform is future work for R (open: T10 in [09-open-decisions.md](09-open-decisions.md#open-for-r-themes)).
