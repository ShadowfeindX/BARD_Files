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

## Pack structure (Proposed)

A pack is a folder of JSON files plus a manifest. JSON is proposed because the Dart SDK reads it with no extra dependency and every editor understands it. (Format is listed for approval in [09-open-decisions.md](09-open-decisions.md#proposed-design-choices-needing-approval).)

```
core/                           pack id
  manifest.json                 id, name, version, engineApi, publisher, requires[], contentHash
  attributes.json
  proficiency.json
  difficulty.json
  derived.json                  formulas (data-only expression trees)
  skills.json                   skills with category and allowed uses (§5)
  conditions.json               condition/affliction templates (§4)
  disorders.json                disorder table (§4)
  sanity_events.json            sanity loss table (§4)
  damage.json                   damage categories (§6)
  vehicles.json                 performance and durability categories (§6)
  ranges.json                   range bands and penalties (§7)
  occult.json                   magic categories, sanity costs (§8)
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

## Loading and validation

1. Read manifest, check `engineApi`.
2. Resolve `requires`.
3. Parse every file into engine value types. Unknown keys are errors, not warnings, so typos in D's edits surface immediately.
4. Cross-validate references (a skill that names an attribute that does not exist, an item referencing an unknown damage category).
5. Produce an immutable `RulesPack` and its `contentHash`.

The validator is part of the engine package so the app, the server and a command-line tool all agree on what "valid" means. A small command-line validator in the engine package (Proposed) lets D check a pack without running the app.

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

- GMs create NPCs, items, skills and techniques as entity templates in their own pack(s). These are ordinary pack files, so they use the same validator.
- The **public library** is a government-style archive showing only items with `verification: verified` (Fixed). Verification is a backend-side flag set by an authorised reviewer, never by the submitting client. The review workflow (who verifies, how) is not specified by R yet and is noted in [09-open-decisions.md](09-open-decisions.md#concerns-raised).
- Library items are copied into a GM's pack when used, with provenance (`source: library/<id>@<version>`), so a library edit never changes a running campaign behind the GM's back.

## Distribution

- The core pack ships inside the apps (offline first) and is also published to the backend so newer versions can be fetched.
- Pack files in the backend are immutable per version; a new version is a new upload.
- The local cache stores every pack version an operation references, so an offline device can always open its operations.

## Documents (Typst, later)

R plans document templating with Typst later: documents stored as text and rebuilt on clients as PDFs. No strict templates now. The architecture leaves a seam: a `DocumentSource` (text + data bindings) stored as pack or campaign content, and a `DocumentRenderer` interface in the app layer. No engine involvement. Choosing how Typst is invoked on each platform is future work for R.
