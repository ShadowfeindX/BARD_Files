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

**Pack shape.** The file list below is the layout; files and fields added for creation profiles, combat defaults and assistance are additive. The repo holds a provisional copy of the example pack (`packages/content_core/assets/example-core/`); the project library holds the version D edits. D's pack is pending (10 §5 "Apply the target pack and engine values").

```
core/                           pack id
  manifest.json                 id, name, version, engineApi, publisher, tier, requires[], verification, contentHash
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
  combat.json                   Proposed (open: API-1): actions per turn
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
- `requires` lets a GM pack extend another pack (for example a campaign pack on top of `core`). Resolution is by id + version range; conflicts are a load error, never a silent override. Pack today: the loader refuses a non-empty `requires` (not supported yet).
- `contentHash` is computed by tooling, not written by hand, and is what an episode pins.

### Skills

A skill is: `name`, `description`, `category`, `attribute`, `proficiency`. There are five categories; they are organizational only and have no mechanical effect. `skills.json` has no "allowed uses" list. "Cast magic" is one roll kind with a Handler-set DC.

### Pack-side values by file

What the game rules mean for each pack file. Field names and shapes marked Proposed are not final (open: [API-1](09-open-decisions.md#api-1-engine-and-pack-api-shapes)). A value D has not given stays `null` in the pack and the feature stays off (CLAUDE.md §9). The engine side of each item is in [01](01-engine.md#rulebook-values-the-engine-uses).

The table gives the target values. The example pack and the engine still hold placeholders or older values for several of them (listed per row as "pack today"); applying the target values is the "Apply the target pack and engine values" row in [10 §5](10-waiting-on-d.md#5-workstream-rows-still-to-schedule).

| File | Content | Shape |
|---|---|---|
| `skills.json` | Mind Shielding is on WIL; Insight's attribute is not yet set (`null`). Planned pack changes: Insight on WIS; Eldritch Lore (INT), Vehicle Modification (INT), Advanced Alchemy, Explosive Disposal and Explosives added as new entries beside the existing Alchemy (the pack keeps Alchemy; the three are not yet in the pack; the "Apply the target pack and engine values" row in [10 §5](10-waiting-on-d.md#5-workstream-rows-still-to-schedule) adds them); categories come from the book's skill list, never reconstructed | data only |
| `occult.json` | The cast attribute is WIL, or the named skill's attribute; `sanityCheckOn` defaults to success and `sanityPayers` is present on success, participants on fail; `ritualDefaults` is Handler guidance only; the `artifact` key holds the book's rule (+1d6, +2 Sanity per category above D) and `focusItem` is `null` until its reduction is given (open: [FE-M5](10-waiting-on-d.md#fe-m5)). As built, the block `ritualDefaults.focusItem` holds the book's rule (+1d6, +2 Sanity per category above D); planned: that block is renamed `artifact` and a new `focusItem` stays `null` (open: [FE-M5](10-waiting-on-d.md#fe-m5) to [FE-M9](10-waiting-on-d.md#fe-m9)). Pack today: `chosenAttribute` and `sanityCheckOptions` are placeholders; there are no `sanityCheckOn`, `sanityPayers` or `artifact` keys | `chosenAttribute: "skill"` with `fallback: "WIL"`, `sanityPayers`: Proposed, open: [API-1](09-open-decisions.md#api-1-engine-and-pack-api-shapes) |
| `difficulty.json` | `checkRules.fumble` is the total, rounded down; `assistance.cap` is the roll attribute's score plus 1 and `assistance.bonus` is a helper's flat attribute score (which attribute: open, [FD-A2](10-waiting-on-d.md#fd-a2)); `luckAdvantage` stays pending and unused (flashback covers its role); difficulties are stated as categories only. Pack today: the fumble `basis` is a placeholder (see the 10 §5 'Apply the target pack and engine values' row) with no `rounding`, and the engine produces no fumble outcome; `assistance.cap` is a placeholder, `assistance.bonus` is `1d6 + var(helperSkillBonus)` and the `luckAdvantage` block is still present with a placeholder | `basis: "total"`, `rounding: "down"`, `{"type": "attributePlus", "plus": 1}`: Proposed, open: [API-1](09-open-decisions.md#api-1-engine-and-pack-api-shapes) |
| `sanity_events.json`, `disorders.json` | Ranges are suggestions the Handler may override; the resist DC follows the Sanity band (20, 40, 60, 80, 100% for Cat-S to Cat-D); half loss rounds down; fumbled resist costs the full loss plus 1; a failed disorder check rolls 1d6. The reworked tables are open ([FD-S3](10-waiting-on-d.md#fd-s3)). Pack today: none of `pick`, `resistDc`, `halfRounding` or `fumbleExtra` exists, the `fumble` entry is a placeholder, and `disorders.json` has `rollDie: null` with a Willpower DC 10 disorder check | `pick: "gm"`, `resistDc.bands`, `halfRounding`, `fumbleExtra`, `rollDie`: Proposed, open: [API-1](09-open-decisions.md#api-1-engine-and-pack-api-shapes) |
| `damage.json`, `threats.json` | Damage dice explode; `min` is a floor on the total damage, and a melee weapon's floor is the greater of its MIN and the STR score. Weapon MIN values stay `null` until they are given. Pack today: `explode` is `null` on every damage category and there is no `meleeFloor` | `meleeFloor`: Proposed, open: [API-1](09-open-decisions.md#api-1-engine-and-pack-api-shapes) |
| `proficiency.json`, `advancement.json` | Proficiency and advancement dice do not explode | `explode: false`, data only. Pack today: every `explode` flag in these two files is `null` |
| `attributes.json`, `proficiency.json` (creation) | Creation limits by character kind: `agent` (also Occult Organization members) and `skald`. Pack today: one attribute range (20 points, 1 to 3 each) in `attributes.json` and one proficiency count (3 Proficient, 1 Expert) in `proficiency.json`, with no profiles | profile names and fields: Proposed, open: [API-1](09-open-decisions.md#api-1-engine-and-pack-api-shapes) |
| `combat.json` | One Major, one Minor and one reaction per turn by default. Pack today: the example pack has no `combat.json` | `actionsPerTurn`: Proposed, open: [API-1](09-open-decisions.md#api-1-engine-and-pack-api-shapes) |
| `tables/` | Random tables are a generic kind; the engine ships no rows, the table content is D's. Pack today: the example pack has no `tables/` folder | as in the structure above |
| `npcs/`, `threats.json` | Human adversaries use attributes, skills and `items/` like a player alias; class numbers apply to supernatural classes only | note for when the enemy defense and attack numbers are given |

Rounding: wherever a pack states a fraction, it states the rounding direction beside it, and the direction favours the player.

Still `null` and not yet given: armor and damage reduction ([G8](10-waiting-on-d.md#g8)), enemy defense and attack ([G11](10-waiting-on-d.md#g11)), advancement purchase limits ([G14](10-waiting-on-d.md#g14)), currency ([Q6](10-waiting-on-d.md#q6)).

### Named variables in pack formulas

Pack formulas and dice expressions are data-only trees. Besides the existing nodes they may use a variable node:

```json
{ "type": "var", "key": "newScore" }
```

It is a named number supplied by the engine at evaluation time. Placements:

| Placement | Expression |
|---|---|
| Advancement: attribute purchase XP, in `advancement.json` | 10 × `var(newScore)` (planned; advancement purchases are not built; 01 Planned code changes) |
| Assistance bonus, in `difficulty.json` | as built: `1d6 + var(helperSkillBonus)`. Planned: the helper's attribute score (key name `helperAttribute`, Proposed, open: [API-1](09-open-decisions.md#api-1-engine-and-pack-api-shapes)) |

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

   Here `since` 1.5.0 and `removeIn` 2 refer to the pack's version. Within a pack major the entry keeps working; removing it is a pack major bump. GMs see the warning in the pack-update summary (planned; 10 §5 'Pack update event') before they choose to apply the update.
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
2. Resolve `requires` (pack today: a non-empty `requires` is refused; not supported yet).
3. Parse every file into engine value types. Unknown keys are errors, not warnings, so typos in D's edits surface immediately.
4. Cross-validate references (a skill that names an attribute that does not exist, an item referencing an unknown damage category).
5. Produce an immutable `RulesPack` and its `contentHash`.

The validator is part of the engine package so the apps and a command-line tool all agree on what "valid" means. A small command-line validator in the engine package (Proposed, open: [API-1](09-open-decisions.md#api-1-engine-and-pack-api-shapes)) lets D check a pack without running the app. As built: `dart run engine:validate_pack <packDir>` (packages/engine/bin/validate_pack.dart); its name and output format are open (API-1).

Backend code (Cloud Functions) does not run the validator (it never imports the engine; see [00-overview.md](00-overview.md#dependency-rules)). Planned (10 §5, pack publishing helper): publishing validates on the publishing device before upload. Every device validates again when it loads a pack (built), so an invalid upload can never be used. Library verification is a human review step, not a server-side check.

## Episodes pin packs

- The pack version pin lives at the **campaign** (campaign level planned, not built; 10 §5 'Campaign-level members and rules'; the episode `packRef` is built) so characters' numbers do not change between missions; the episode-scoped pack tier stays below it. An episode records `packRef = (id, version, contentHash)` in its meta when created.
- **Pack updates are manual by default.** When a newer pack version exists the GM sees it, with a summary of what changed (planned; 10 §5 'Pack update event'), and chooses when to apply. Applying records a `PackUpdated(from, to)` event (planned; not built, 10 §5), so the log shows exactly when values changed.
- **Engine updates are automatic by default** within a major. The GM toggles for both live in episode settings and are stored in episode meta.
- Because events carry resolved results, a pack update never changes past outcomes.

## Content kinds and tiers

| Tier | Who creates | Where it lives | Shown in public library |
|---|---|---|---|
| Core | D (official) | cloud-hosted, bundled copy in apps (cloud/account parts planned; see 06) | yes |
| Library | any GM, submitted for review | cloud-hosted | only once verified |
| Campaign / private | a GM | the GM's account (and local cache) (cloud/account parts planned; see 06) | no |
| Episode-scoped | a GM, for one episode | pinned to that episode | no |

- The **episode-scoped tier** sits under Campaign and holds per-episode GM content. It uses the same schema and the same validator as any pack, is pinned by the episode (`packRef`), and, once PackUpdated is built, its use is logged like any other pack change (planned; 10 §5 'Pack update event').
- GMs create NPCs, items, skills and techniques as entity templates in their own pack(s) (planned; 10 §5 'GM pack authoring'). These are ordinary pack files, so they use the same validator.
- The **public library** is a government-style archive showing only items with `verification: verified`.
- Planned (10 §5): library verification, the Firestore library, Cloud Storage distribution and the offline cache are not built.
- **Who verifies.** At first only R and D hold the verification claim. It is set by the roles function; more auditors can be added later via the console.
- **Revocable.** Verification can be revoked: the item goes back to pending, with a reason. Copies already in GMs' packs are unchanged.
- **Record.** Each library item records the verifier, the date and the version verified.
- **Where it lives.** The library lives in Firestore. Verification is written by the reviewer's client under Firestore rules, never by the submitting client; a function can take it over later if the rules get awkward. See [06-accounts-backend.md](06-accounts-backend.md).
- Library items are copied into a GM's pack when used, with provenance (for example `libraryRef: library/<id>@<version>`; the field name is Proposed (open: [API-1](09-open-decisions.md#api-1-engine-and-pack-api-shapes)) and must not reuse the stripped `source` annotation key), so a library edit never changes a running campaign behind the GM's back.

## Distribution

Planned (10 §5): Cloud Storage, the pack index and the offline cache are not built; today the core pack ships bundled.

- The core pack ships inside the apps (offline first) and is to be published to the backend so newer versions can be fetched.
- Pack files live in Cloud Storage and the pack index lives in Firestore. Pack files are immutable per version; a new version is a new upload.
- The local cache stores every pack version an episode references, so an offline device can always open its episodes.

## Documents (Typst, later)

Document templating with Typst comes later: documents stored as text and rebuilt on clients as PDFs. No strict templates now. The architecture leaves a seam: a `DocumentSource` (text + data bindings) stored as pack or campaign content, and a `DocumentRenderer` interface in the app layer. No engine involvement. Choosing how Typst is invoked on each platform is future work for R (open: [T10](09-open-decisions.md#t10)).
