# 10. Proposals pending D

Status: **for R's meeting with D** (Thursday 2026-10-22 at the earliest). Nothing here is approved. Each section states what is undecided, what is already fixed around it, the options, and a recommendation. Once R and D rule, the result moves into the chapter named in each section and this file shrinks.

Rulebook references cite the canonical PDF (`BARD Core Rulebook.pdf`) by page; "1.3.1" is the older reference book (Beta 1.1). The rulebook coverage report and the example pack named below live in the project library, not in this repository.

This file covers only the items R set for the meeting. The other rulebook gaps that need D (fumbles, advantage, exploding dice, sanity values, death and injury, armor, action economy and others) are tracked separately in the project library's `rulebook/rulebook-gaps.md`.

## 1. Occult check attribute (C5 / G6)

**Undecided:** which attribute the occult check adds.

**Already fixed:** skills carry their own attribute (F3 part 2). By design, pack-declared attributes can be used on any check.

The rulebook gives three answers in one chapter (coverage report C5):

| Source | Formula |
|---|---|
| p29 "Occult Action Check" | `1D6 + (WIL/INT) + Proficiency` |
| p29 "Casting & Rituals", p30 Casting Flow step 3 | `1d6 + relevant Attribute (WIS or INT) + Skill bonus + modifiers` |
| p29 prerequisite text | Needs "a rank in an appropriate Willpower (WIL) Proficiency" |
| 1.3.1 | "WIS or INT" in the intro, "1d6 + WIL" in the casting flow |
| Dossier P-01-B (evidence, not canon) | Ritual Magic, Advanced Alchemy, Exorcism, Forbidden Rituals, Mind Shielding under WIL; Arcane Knowledge, Occult Lore under INT; Cult Tactics under WIS |

"Mind Shielding" appears in the p29 prerequisite list and on the dossier but not in the §5 skill list.

**Options:**
- A. WIL for every occult check (1.3.1 casting flow, the p29 WIL prerequisite and the dossier).
- B. WIL or INT (p29 Occult Action Check).
- C. WIS or INT (p29 Casting & Rituals, p30 step 3).
- D. The attribute of the skill the player names for the cast (the dossier grouping becomes the core pack's default skill attributes).

These are the options in the example pack's `occult.json`. **Recommendation (coverage report, decision 2):** WIL by default, or the attribute of the skill the player names (A or D).

## 2. The occult system (F3 part 1, G6)

**Undecided:** whether "cast magic" is one roll kind with a GM-set DC, and how much of the provisional `OccultSystem` stays.

**Already fixed:** sanity loss amounts come from the rules and the GM may edit any consequence value before broadcast (F2); rolls are never gated.

R's game-rules model (2026-10-16) gives spells no schema; trimming `OccultSystem` to match is what needs D. The provisional `OccultSystem` ([01-engine.md](01-engine.md)) owns occult action checks, ritual time and participants, focus items and sanity cost. The rulebook's p29 rules: ritual time 1 hour per base DC point; each participant makes a DC 10 occult check for +1 to the caster; a focus item gives +1d6 and +2 Sanity cost per category above D.

**Proposal (coverage report, decision 20):** one roll kind, "cast magic": the GM sets the DC as a category, the roll uses the attribute from §1 (the example pack writes it as `1d6 + [attribute] + skill bonus + modifiers`, with the proficiency bonus as an additional die per G16), and the sanity cost follows the category. Ritual time, participants and focus items are GM-described, unless D wants them as optional defaults the GM can apply.

**Open details D should settle with it (G6):**
- Sanity check on every cast, or only on success (p30 Casting Flow step 5 vs 1.3.1).
- Who pays Sanity in group casting (p29 is silent; 1.3.1 says all pay half).
- Which category a focus item's "+2 Sanity per category above D" counts: the item's or the spell's.
- Whether a rank in a WIL occult proficiency is a hard prerequisite (p29 says so) or a GM call.

The coverage report's recommendation (decision 15): sanity check on every cast; group casters pay half, rounded up; the focus item counts the spell's category. These are the report's reading of the book, not rulings.

## 3. Pack shape (P3)

**Undecided:** the exact files, fields and details of a content pack.

**Already fixed:** JSON + manifest; one validator in the engine; unknown keys are errors in shipped packs; authoring annotations are stripped before shipping; the `var` formula node; skill = name, description, category, attribute, proficiency; operation-scoped packs for per-session GM content.

An example pack built from the rulebook is in the project library under `packs/`:
- `example-core/`: `manifest.json`, `attributes.json`, `derived.json`, `skills.json`, `proficiency.json`, `difficulty.json`, `advancement.json`, `damage.json`, `conditions.json`, `sanity_events.json`, `disorders.json`, `occult.json`, `threats.json`, `ranges.json`, `vehicles.json`, plus `items/`, `npcs/`, `techniques/`, `strings/`.
- `example-operation/`: an operation-scoped pack with its own `manifest.json` and `skills.json`.

Its annotation keys and `null` values mark the values the book leaves open that it could place in a file (death and critical injury, for example, has no file yet). **Ask of D:** walk the example, confirm the split into files reads naturally for authoring, and flag any field that should be renamed, merged or dropped. Field names are provisional until then; for example, the library provenance field must not reuse the stripped `source` annotation key.

## 4. Web hosting (W1 revisit)

**Undecided:** whether the web build should ever host operations.

**Already fixed:** for now the web build is player-only (join, play, phone); every hosting mode lives in native builds. The apps already read hosting modes from a per-platform capability set ([07-apps.md](07-apps.md)), so a change is configuration, not structure.

R's reason for player-only ([07-apps.md](07-apps.md)): a web GM loses control over engine version, pack choice and modifying their own games. **Question for D:** does onboarding new users (trying the game without installing anything) need a web GM? If yes, web hosting would likely be limited to the RTDB relay and P2P, since browsers cannot host LAN (concern 2).

## 5. Physical dice (concern 7)

**Undecided:** whether to build the feature.

**Already fixed:** `CheckResolved` reserves `source` (`rng` | `entered`, plus who entered: GM or alias), so the event shape does not change if the feature is built.

**Design as specified by R:**
- Players may roll real dice, including remote players not in the same room as the GM, and enter the faces on their own clients. The faces travel to the GM with the request.
- A per-operation GM setting, off by default, allows physical dice. Without it, entered faces are refused, so the GM never mistakes player-entered values for app rolls.
- The setting is agreed between the GM and players per operation.
- Entered faces are recorded with `source: entered` and who entered them.
- Proposed extension (not yet ruled): entered faces, like app rolls, are never re-rolled or altered (F2).

**Ask of D:** approve the feature for the game, or keep it out of v1.
