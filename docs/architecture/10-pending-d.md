# 10. Proposals pending D

Status: **for R's meeting with D** (Thursday 2026-10-22 at the earliest). Nothing here is approved. Each section states what is undecided, what is already fixed around it, the options, and a recommendation. Once R and D rule, the result moves into the chapter named in each section and this file shrinks.

Rulebook references cite the canonical PDF (`BARD Core Rulebook.pdf`) by page. The rulebook coverage report and the example pack named below live in the project library, not in this repository.

## 1. Occult check attribute (C5 / G6)

**Undecided:** which attribute the occult check adds.

**Already fixed:** the engine supports any attribute on any check; skills carry their own attribute (F3 part 2).

The rulebook gives three answers in one chapter (coverage report C5):

| Source | Formula |
|---|---|
| p29 "Occult Action Check" | `1D6 + (WIL/INT) + Proficiency` |
| p29 "Casting & Rituals" | `1d6 + relevant Attribute (WIS or INT) + Skill bonus + modifiers` |
| Dossier P-01-B (evidence, not canon) | Ritual Magic, Advanced Alchemy, Exorcism, Forbidden Rituals, Mind Shielding under WIL; Arcane Knowledge, Occult Lore under INT; Cult Tactics under WIS |

"Mind Shielding" appears in the p29 prerequisite list and on the dossier but not in the §5 skill list.

**Options:**
- A. Fixed attribute for every occult check (WIL, per the casting flow and dossier).
- B. The attribute of the skill the player names for the cast (the dossier grouping becomes the core pack's default skill attributes).
- C. GM picks per cast.

**Recommendation (coverage report, decision 2):** A or B; the report leans to WIL by default, or the named skill's attribute. D decides which reads best at the table.

## 2. The occult system (F3 part 1, G6)

**Undecided:** whether "cast magic" is one roll kind with a GM-set DC, and how much of the provisional `OccultSystem` stays.

**Already fixed:** spells have no schema (R's game-rules model); sanity loss amounts come from the rules and the GM may edit any consequence value before broadcast (F2); rolls are never gated.

The provisional `OccultSystem` ([01-engine.md](01-engine.md)) owns occult action checks, ritual time and participants, focus items and sanity cost. The rulebook's p29 rules: ritual time 1 hour per base DC point; each participant makes a DC 10 occult check for +1 to the caster; a focus item gives +1d6 and +2 Sanity cost per category above D.

**Proposal (coverage report, decision 20):** one roll kind, "cast magic": the GM sets the DC as a category, the roll uses the attribute from §1 plus proficiency, and the sanity cost follows the category. Ritual time, participants and focus items are GM-described, unless D wants them as optional defaults the GM can apply.

**Open details D should settle with it (G6):**
- Sanity check on every cast, or only on success (p29 step 5 vs 1.3.1).
- Who pays Sanity in group casting (p29 is silent; 1.3.1 says all pay half).
- Which category a focus item's "+2 Sanity per category above D" counts: the item's or the spell's.
- Whether arcane proficiency is a hard prerequisite (p29 says so) or a GM call.

The coverage report's recommendation (decision 15): sanity check on every cast; group casters pay half, rounded up; the focus item counts the spell's category. These are the report's reading of the book, not rulings.

## 3. Pack shape (P3)

**Undecided:** the exact files, fields and details of a content pack.

**Already fixed:** JSON + manifest; one validator in the engine; unknown keys are errors in shipped packs; authoring annotations are stripped before shipping; the `var` formula node; skill = name, description, category, attribute, proficiency; operation-scoped packs for per-session GM content.

An example pack built from the rulebook is in the project library under `packs/`:
- `example-core/`: `manifest.json`, `attributes.json`, `derived.json`, `skills.json`, `proficiency.json`, `difficulty.json`, `advancement.json`, `damage.json`, `conditions.json`, `sanity_events.json`, `disorders.json`, `occult.json`, `threats.json`, `ranges.json`, `vehicles.json`, plus `items/`, `npcs/`, `techniques/`, `strings/`.
- `example-operation/`: an operation-scoped pack with its own `manifest.json` and `skills.json`.

Its annotation keys mark every value the book leaves open. **Ask of D:** walk the example, confirm the split into files reads naturally for authoring, and flag any field that should be renamed, merged or dropped. Field names are provisional until then (for example, the library provenance field and the authoring `source` annotation share a name today).

## 4. Web hosting (W1 revisit)

**Undecided:** whether the web build should ever host operations.

**Already fixed:** for now the web build is player-only (join, play, phone); every hosting mode lives in native builds. The session already exposes available hosting modes per platform, so a change is configuration, not structure.

R's reason for player-only: a web GM loses control over engine version, pack choice and modifying their own games. **Question for D:** does onboarding new users (trying the game without installing anything) need a web GM? If yes, web hosting would be limited to the RTDB relay and P2P (no LAN on the web).

## 5. Physical dice (concern 7)

**Undecided:** whether to build the feature.

**Already fixed:** `CheckResolved` reserves `source` (`rng` | `entered`, plus who entered: GM or alias), so the event shape does not change if the feature is built.

**Design as specified by R:**
- Players may roll real dice, including remote players not in the same room as the GM, and enter the faces on their own clients. The faces travel to the GM with the request.
- A per-operation GM setting, off by default, allows physical dice. Without it, entered faces are refused, so the GM never mistakes player-entered values for app rolls.
- The setting is agreed between the GM and players per operation.
- Entered faces are recorded with `source: entered` and who entered them, and are never re-rolled or altered.

**Ask of D:** approve the feature for the game, or keep it out of v1.
