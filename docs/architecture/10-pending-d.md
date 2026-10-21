# 10. Pending D: post-meeting decision kit

Status: **for R's meeting with D** (Thursday 2026-10-22 at the earliest). Nothing in this chapter is approved. It lists everything that has to be handled after the meeting, one card per decision, so that a ruling becomes a small, mechanical edit.

Every card has the same parts:

- **Decides:** D, R, or R and D. **Source:** where the question and its evidence are.
- **Today:** what `main` already does about it (usually: the value is `null`, the feature is off).
- **Options:** one row per option, with the exact spec sections, code (implementation-plan row and file) and pack files that change if R and D pick it.
- **Assumption:** the option the rest of the work is prepared for. It is the coordinator's existing recommendation, **not a ruling**. Nothing is built on an assumption: the pack keeps `null` and the feature stays off until the ruling (CLAUDE.md §9).

Conventions:

- Spec chapters are cited as `01 §Heading` (this folder). Code paths are relative to the repository root; `engine/` is `packages/engine/lib/src/`. Line numbers are on `main` at the time of writing and drift; the symbol name is the stable reference.
- "Row N" is a workstream in the project library's `architecture/implementation-plan.md`. "Row N follow-up" means a new branch on top of what row N merged. "New row" means work the plan does not have yet.
- **Pack** means the provisional pack `packages/content_core/assets/example-core/` (the authoring source; `tool/build_pack.sh` regenerates the shipped copy). The library copy `packs/example-core/` gets the same edit until D's pack replaces both.
- Rulebook pages are PDF pages of `BARD Core Rulebook.pdf`; "1.3.1" is the older reference book. Plain-language versions of the D questions are in the meeting packet (project library `meeting/`).

## How to apply a ruling

1. Write the ruling into the **Ruled** column of the [index](#index) (date and R's or D's words), and add a row to the [09 decisions record](09-open-decisions.md#decisions-record-ruled-by-r-2026-10-20).
2. Do the edits listed under the chosen option, on a branch named for the work (`feature/`, `bugfix/` or `docs/`), with the developer guide and `CHANGELOG.md` in the same PR (CLAUDE.md §10).
3. For a pack value: replace the `null` (and remove its annotation) in the pack, run `bash tool/build_pack.sh`, and check that the path left `RulesPack.pendingPaths` (`engine/pack/rules_pack.dart`). If the ruling adds a field, the parser in `engine/pack/files/` and the pack loader tests change with it.
4. Delete the card from this chapter, or shorten it to "Ruled, see 09". Remove the gap from the library's `rulebook/rulebook-gaps.md` and from the pack's `openItems`.
5. If D picks something no option here covers, the card is re-planned before any code, and the plan goes to R.

## Index

| # | Question (short) | Decides | Assumption | Ruled |
|---|---|---|---|---|
| [M1](#m1-occult-check-attribute-c5--g6) | Occult check attribute | D (with R) | WIL, or the named skill's attribute | |
| [M2](#m2-cast-magic-and-the-occult-system-f3-part-1) | "Cast magic" as one roll; how much of `OccultSystem` stays | D | One roll, GM-set DC; ritual parts GM-described | |
| [M3](#m3-casting-details-g6) | Sanity timing, group cost, focus category, prerequisite | D | Every cast; half each, rounded up; spell's category; warning only | |
| [P1](#p1-pack-shape-p3) | Pack files and fields | D | Example pack shape as is | |
| [P2](#p2-skill-list-g15) | Mind Shielding, three missing attributes, paired skills | D | Add it; INT, INT, WIS; keep pairs | |
| [W1](#w1-web-hosting) | Web GM hosting for onboarding | D | Stay player-only | |
| [C7](#c7-physical-dice-concern-7) | Physical dice | D | Approve, built after the demo | |
| [G1](#g1-fumble) | Fumble basis | D | Total, rounded down | |
| [G2](#g2-advantage-and-disadvantage) | Advantage and disadvantage | D | GM grants; disadvantage keeps worst | |
| [G3](#g3-which-dice-explode) | Which dice explode | D | Primary d6 and damage dice only | |
| [G4](#g4-and-g18-assistance) | Assistance cap and helper bonus (with G18) | D | Cap 3; helper adds own proficiency die | |
| [G5](#g5-sanity-loss) | Sanity amounts, resist DC, rounding, disorder roll | D | Roll in range; DC by category; round up; d6 on fail | |
| [G7](#g7-dying-and-critical-injury) | Death and critical injury | D | 1.3.1 death rule; optional injury table | |
| [G8](#g8-armor-and-damage-reduction) | Armor values and DR | D | Flat DR; light 1-2, medium 3-4, heavy 5+ | |
| [G9](#g9-weapon-min-and-melee-strength) | Weapon MIN; STR in melee | D | MIN = lowest damage; no STR | |
| [G10](#g10-action-economy-aim-dodge) | Actions per turn, Aim, Dodge | D | 1 Major + 1 Minor; Aim Minor +1; Dodge any, Parry melee | |
| [G11](#g11-enemy-numbers) | Enemy defense, attack, speed | D | Defense and attack from the class skill bonus | |
| [G13](#g13-old-difficulty-names) | Old difficulty names | D | Drop; restate as categories | |
| [G14](#g14-advancement-purchases) | "Single use"; Artifact Clearance | D | Once per character; GM-tracked note | |
| [G19](#g19-creation-totals) | Exact or at most 20 points / 3+1 skills | D | Exact | |
| [C1](#c1-content-cut-since-131) | Was content cut since 1.3.1 on purpose? | D | None restored without D | |
| [X0](#x0-which-unit-owns-the-event-log-q24) | Which unit owns the event log (Q24) | R and D | A: one log per operation, mission segments | |
| [Q5](#q5-requests-between-sittings) | Requests between sittings; auto-confirm purchases | R | Queue under the operation; no auto-confirm | |
| [Q7](#q7-messages-between-sessions) | Where messages between sessions live | R | The operation's phone box | |
| [Q9](#q9-published-mission-content) | Published mission content and id | R | Debriefs + public text log; id from `MissionStarted` | |
| [Q33](#q33-anonymous-accounts-browsing) | Anonymous accounts browsing the library | R and D | Play yes, browsing no | |
| [Q6](#q6-currency) | Currency | D | Pack data + generic `Funds` | |
| [Q12](#q12-fake-websites) | Fake websites: authors, sharing | D | Handlers, per operation; library later | |
| [N1](#n1-narrator-lines-and-name-reveals) | Name reveals (D1-D7) and how lines are produced (R1-R5, decision 15) | D and R | Hybrid + `RevealName` | |
| [F1](#f1-mission-library-seed-cases) | Seed cases for the mission library | D | None until D lists them | |
| [F2](#f2-sign-in-code-symbology) | Sign-in code as PDF417 | D | No assumption; rendering choice only | |

Not in this chapter: R's own open questions that do not wait on the meeting (decisions 4, 11 and 14 of 2026-10-21, answered in the library's `architecture/r-questions-4-11-13-15.md`), and decision 13 (GM notes) except its "per operation or per mission" part, which is under [X0](#x0-which-unit-owns-the-event-log-q24). Payments stay deferred (concern 6).

---

## Magic

### M1. Occult check attribute (C5 / G6)

**Decides:** D (attribute check with R). **Source:** library `rulebook/rulebook-gaps.md` G6; coverage report C5, decision 2.
**Today:** `occult.json` is pending D as a whole: kept raw in `RulesPack.occultPending`, not validated, not used (`engine/pack/load/pack_loader.dart`, the `occult.json` branch). A check already takes any pack attribute, or the named skill's attribute (`CheckSystem._spec`).

The book gives three answers:

| Source | Formula |
|---|---|
| p29 "Occult Action Check" | `1D6 + (WIL/INT) + Proficiency` |
| p29 "Casting & Rituals", p30 Casting Flow step 3 | `1d6 + relevant Attribute (WIS or INT) + Skill bonus + modifiers` |
| p29 prerequisite text | Needs "a rank in an appropriate Willpower (WIL) Proficiency" |
| 1.3.1 | "WIS or INT" in the intro, "1d6 + WIL" in the casting flow |
| Dossier P-01-B (evidence, not canon) | Ritual Magic, Advanced Alchemy, Exorcism, Forbidden Rituals, Mind Shielding under WIL; Arcane Knowledge, Occult Lore under INT; Cult Tactics under WIS |

| Option | Spec | Code | Pack |
|---|---|---|---|
| **A. WIL always** | 01 §Rulebook gaps item 5 becomes settled; 01 §Systems `OccultSystem` row | M2's cast-magic roll fixes `attribute: WIL` | `occult.json` `castMagic.chosenAttribute: "WIL"`; drop `attributeOptions` |
| B. WIL or INT (player's choice) | as A, plus "player chooses" | cast command takes `attribute`, refused unless WIL or INT | `chosenAttribute: ["WIL", "INT"]` |
| C. WIS or INT | as B | as B with WIS, INT | `chosenAttribute: ["WIS", "INT"]` |
| **D. The named skill's attribute** | as A, plus "falls back to the skill's attribute" | no new code: `CheckSystem._spec` already uses the skill's attribute; the cast roll falls back to A when no skill is named | `chosenAttribute: "skill"` with `fallback: "WIL"`; set the occult skills' `attribute` in `skills.json` from the dossier grouping |

**Assumption:** A with D: WIL by default, or the attribute of the skill the player names (coverage report decision 2). The pack field name `chosenAttribute` is Proposed.

### M2. Cast magic and the occult system (F3 part 1)

**Decides:** D. **Source:** 09 F3; rulings log 2026-10-20 (F3 part 1 deferred); coverage report decision 20.
**Today:** no `OccultSystem` in code (01 lists it as Provisional). Spells have no schema (R's game-rules model, 2026-10-16). Sanity loss is GM-entered and goes through the review gate (F2).

| Option | Spec | Code | Pack |
|---|---|---|---|
| **A. One roll kind, GM-set DC; ritual time, participants, focus items are GM-described** | 01 §Systems: `OccultSystem` row shrinks to "cast magic"; 01 §Commands and events: Proposed `CastMagic` command or a `RequireCheck` kind; 02 §Pack structure: `occult.json` fields | New row (occult, Opus-Engine): either a `kind: castMagic` on `RequireCheck` (`engine/commands/check_commands.dart`) or a new command in `CheckSystem`; sanity cost is suggested from `sanityCostByCategory` and entered through `VitalsSystem` like any loss; parser `engine/pack/files/occult.dart` (new); loader stops treating the file as pending; codecs (row 6: `protocol/lib/src/command_codec.dart`, fixtures); narrator case | `occult.json`: keep `rollKindProposal`, `rollFormula`, `sanityCostByCategory`; drop `ritualDefaults` |
| B. As A, with ritual parts as optional defaults the GM can apply | as A, plus 01 note on defaults | as A, plus modifiers the GM can add from `ritualDefaults` (participant +1 each, focus +1d6) as labelled `CheckModifier`s; ritual time is text only | keep `ritualDefaults`; `focusItem.bonus.explode` waits on G3 |
| C. Full `OccultSystem` (occult action checks, rituals, participants, focus items as rules) | 01 §Systems as written today | as B, plus participant checks (DC 10) as sub-checks and a focus-item component (`engine/components/components.dart`) | as B, plus focus items in `items/` |

**Assumption:** A (coverage report decision 20). B is a cheap extension if D wants the p29 numbers to hand.

### M3. Casting details (G6)

**Decides:** D. **Source:** `rulebook-gaps.md` G6; 10 §2 open details (previous version of this chapter); coverage report decision 15. Only needed if M2 is A or B.

| Detail | Options | Changes | Assumption |
|---|---|---|---|
| Sanity check timing | (a) every cast (p30 step 5); (b) only on success (1.3.1) | `occult.json` `sanityCheckOn: "everyCast" \| "success"`; the cast's follow-up suggestion in the new occult code | (a) |
| Group casting cost | (a) each caster pays half, rounded up (1.3.1); (b) caster pays all; (c) each pays full | `occult.json` `groupCost`; suggestion per participant in the review tray (row 8 follow-up) | (a) |
| Focus item category | (a) the spell's category; (b) the item's | `occult.json` `focusItem.categoryFrom: "spell" \| "item"` | (a) |
| Arcane proficiency prerequisite | (a) warning the GM can override; (b) hard refusal | (a) a warning on the pending check; (b) a `RejectionCode` in `engine/engine.dart` and its codec | (a) |

The coverage report's reading of the book, not rulings.

---

## Content pack

### P1. Pack shape (P3)

**Decides:** D. **Source:** 09 P3; library `packs/example-core/README.md` (tour with layout questions).
**Already fixed:** JSON + manifest; one validator; unknown keys are errors in shipped packs; annotations stripped (`_`-prefixed keys too); `null` is the single pending-D marker; the `var` node; skill = name, description, category, attribute, proficiency; operation-scoped packs.
**Today:** the loader (row 4, merged) reads the provisional shape, one parser per file in `engine/pack/files/`.

| Option | Spec | Code | Pack |
|---|---|---|---|
| **A. Keep the example shape** | 02 §Pack structure: file list becomes Fixed; 09 P3 row | none; developer guide `docs/developer-guide/packs.md` drops "Provisional" | none |
| B. Rename, merge or drop named fields or files | 02 §Pack structure | per renamed file: its parser in `engine/pack/files/`, the file list `packFiles` in `pack_loader.dart`, `RulesPack` fields, loader tests; renames inside a major follow 02 §Deprecation in packs (additive + deprecation) | the named files, in both copies |
| C. D supplies a new pack | 02 §Pack structure | as B, file by file | replace `example-core/` in `content_core`; README of `content_core` |

The `difficulty.json` `checkRules` block sits there as a proposal (`_shapeNote`); D and R may move it. The library provenance field must not reuse the stripped `source` key.

**Assumption:** A, with D's renames applied as B.

### P2. Skill list (G15)

**Decides:** D. **Source:** `rulebook-gaps.md` G15.
**Today:** `skills.json` has Mind Shielding (`mind_shielding`) and `attribute: null` for the skills without one; a check on such a skill is refused until the GM names an attribute (`CheckSystem._spec`, "pending D").

| Option | Changes | |
|---|---|---|
| **Add Mind Shielding; Eldritch Lore INT, Vehicle Modification INT, Insight WIS (2.1); keep paired skills separate** | `skills.json` attributes; remove the G15 `openItems` entry; no code | **Assumption** |
| Other attributes | same file | |
| Drop Mind Shielding | `skills.json`; M1 option D loses one WIL skill | |
| Merge Alchemy / Advanced Alchemy or Explosive Disposal / Explosives | `skills.json`; deprecation records if the pack has shipped (02 §Deprecation in packs) | |

---

## Platform and features

### W1. Web hosting

**Decides:** D. **Source:** 09 W1; 07 §Web build role.
**Today:** the web build is player-only. Hosting modes come from a per-platform capability set (`canHost`, `canEditPacks`), so a change is configuration.

| Option | Spec | Code |
|---|---|---|
| **A. Stay player-only** | 09 W1 row: "confirmed with D" | none |
| B. Web GM limited to RTDB relay and P2P (no LAN) | 07 §Web build role; 04 §Play modes (web host row); 09 W1, concern 2; P12 web-host autosave (no sembast file: RTDB head only) | capability set in `apps/bard` (row 8 follow-up); `sembast_web` host store (row 12 follow-up); relay (row 15) |

**Assumption:** A (R's reason: a web GM loses control over engine version, pack choice and modifying their own games). B only if D needs it for onboarding.

### C7. Physical dice (concern 7)

**Decides:** D. **Source:** 09 concern 7.
**Today:** `CheckResolved` carries `source` (`rng` | `entered`) and `enteredBy` (`engine/events/check_events.dart`); only `rng` is produced.

| Option | Spec | Code |
|---|---|---|
| **A. Approve** | 01 §Commands and events: entered faces; 04 §Play modes; 03 §Message bodies (faces on the request); 09 concern 7 | Row 5 follow-up: `ResolveCheck` takes optional `faces`, validated against the dice the check would roll, refused unless the operation allows it; `OperationSettings` (`engine/state/operation_state.dart`) gains `allowPhysicalDice` (default `false`) and its codec (`protocol/lib/src/shared_codec.dart`); player request carries faces (row 7); GM setting and entry UI (row 8 follow-up); `ui_kit` dice breakdown marks entered faces |
| B. Keep out of v1 | 09 concern 7: "out of v1"; field stays reserved | none |

The design as R specified it: a per-operation GM setting, off by default and agreed with the players; entered faces are recorded with `source: entered` and who entered them. Proposed, not ruled: entered faces, like app rolls, are never re-rolled or altered (F2).

**Assumption:** A, scheduled after the demo slice.

---

## Rulebook gaps

Values D has not given. The engine can represent each variant; agents never choose (CLAUDE.md §9). Source for all: library `rulebook/rulebook-gaps.md` and the coverage report. Each card's **Assumption** is the "possible answer" in that file.

### G1. Fumble

**Today:** `CheckRules.fumbleFractionOfDc` is loaded (0.25, `engine/pack/files/difficulty.dart`); `fumble.basis` is `null`; `CheckOutcome` has no fumble and fumbles are off (`CheckSystem` doc comment).

| Option | Spec | Code | Pack |
|---|---|---|---|
| **A. Total, rounded down** | 01 §Dice and checks: fumble rule | Row 5 follow-up: `CheckOutcome.fumble` (`engine/checks/check_types.dart`); `CheckSystem._outcome` tests `total <= floor(fraction × dc)` before partial success; codec value and fixture (`protocol/lib/src/event_codec.dart`); narrator line (`engine/narrator/narrator.dart`); `ui_kit` dice breakdown label; parser reads `basis` and `rounding` | `difficulty.json` `checkRules.fumble.basis: "total"`, `rounding: "down"` |
| B. Primary die alone | same | same, comparing the primary die's first face | `basis: "primaryDie"` |

"Immediate complications" on a sanity fumble is G5.

### G2. Advantage and disadvantage

**Today:** `luckAdvantage` is loaded (`extraPrimaryDiceFrom: LCK`, `keep: bestTotal`); `grantedBy` is `null`; not built.

| Option | Spec | Code | Pack |
|---|---|---|---|
| **A. GM grants it per check; disadvantage = roll the same extra dice and keep the worst** | 01 §Dice and checks | Row 5 follow-up: `RequireCheck` gains `advantage: none \| advantage \| disadvantage`; roll draws extra primary dice and keeps best or worst total; breakdown shows every set; codec + fixture; GM control (row 8 follow-up) | `difficulty.json` `luckAdvantage.grantedBy: "gm"`, `disadvantageKeep: "worstTotal"` |
| B. D lists triggers | 01 as A, plus a trigger list | as A, plus GM prompts per trigger | `grantedBy` as a list (field shape to plan) |

### G3. Which dice explode

**Today:** every `explode: null` in the pack means "not ruled"; the evaluator rolls `null` as not exploding (`Dice.explodes` in `engine/expr/expr.dart`). Only the primary die is `true`.

| Option | Pack | Code |
|---|---|---|
| **A. Primary d6 and damage dice; not proficiency, helper, focus or advantage dice** | `damage.json` and `threats.json` damage dice `explode: true`; `proficiency.json`, `advancement.json`, the `difficulty.json` assistance die and the `occult.json` focus die `false` | none (data only); tests for exploding damage |
| B. Every die (p11 first sentence) | all `explode: true` | none |
| C. Primary die only (p11 second sentence) | all others `false` | none |

### G4 and G18. Assistance

**Today:** `assistance` is loaded (gate Cat-D, bonus `1d6 + var(helperSkillBonus)`), `cap` is `null`; assistance is not built. `helperSkillBonus` has no defined value since proficiency became dice (G16).

| Part | Options | Spec | Code | Pack |
|---|---|---|---|---|
| Helper bonus (G18) | **(a) helper rolls their own proficiency die: 1d6 + 1d4 Proficient, 1d6 + 1d6 Expert, 1d6 untrained**; (b) a flat number D gives | 01 §Dice and checks; 02 §Named variables (the `var` placement changes) | New: assistance in `CheckSystem` (row 5 follow-up): helper's gate check, then the bonus; for (a) the `helperSkillBonus` var is replaced by the helper's tier expression, so `engine/expr/vars.dart` drops it (deprecation per 01 §Deprecation if any pack shipped it) | (a) `difficulty.json` `assistance.bonus` becomes `1d6` + `{"type":"helperProficiency"}` (new node, Proposed) or the loader adds the tier die; (b) keep the `var` |
| Cap (G4) | **(a) 3 helpers on ordinary checks**; (b) no cap; (c) another number | 01 §Dice and checks | refusal code `tooManyHelpers` (Proposed) | `assistance.cap: 3` or `null` replaced by `"none"` |
| Ritual helpers (p29) | keep as written (DC 10, +1 each) | M2 | M2 option B or C | `occult.json` |

**Assumption:** (a) and (a). Assistance stays off until both are ruled.

### G5. Sanity loss

**Today:** GM enters every sanity amount; `VitalsSystem` holds it for review (F2). `sanity_events.json` has ranges with `null` placeholders; `disorders.json` `rollDie` is `null`.

| Part | Assumption | Other options | Code | Pack |
|---|---|---|---|---|
| Amount in a range | Rolled within the range; GM can override before broadcast (already ruled: sanity loss hard-coded, GM override) | GM picks; midpoint | `VitalsSystem` follow-up: suggest a rolled amount from the event's range | `sanity_events.json` `pick: "roll"` |
| Resist DC | A default per trauma category | one fixed DC; GM sets | resist check is an ordinary `RequireCheck` | `sanity_events.json` `resistCategory` per event |
| Half loss rounding | Up | down | suggestion arithmetic | `halfRounding: "up"` |
| Anomalous attack damage | Partial success costs half | full | `VitalsSystem` suggestion | `sanity_events.json` or `threats.json` flag |
| Fumble on resist | Full + 1 and a GM-described complication | D's rule | needs G1 | `fumbleExtra: 1` |
| Disorder roll | Failed WIL DC 10 check rolls 1d6 on the table | GM picks | `ConditionSystem` follow-up | `disorders.json` `rollDie: {"type":"dice","count":1,"sides":6}` |

### G7. Dying and critical injury

**Today:** `VitalsSystem` does not clamp; nothing happens at or below 0 (its doc comment).

| Option | Spec | Code | Pack |
|---|---|---|---|
| **A. 1.3.1 death rule (damage past 0 accumulates; more than END = death); six-entry injury table as optional base content; injury check at a real category** | 01 §Systems `VitalsSystem` | New row (vitals rules): incapacitated and dead states as components or conditions; injury check as `RequireCheck`; table roll; review gate applies | new `injuries.json` (or a `damage.json` block): table rows from 1.3.1 (needs a PC extraction, never reconstructed); `criticalInjury.checkCategory` |
| B. D writes a new rule | same | per D | per D |
| C. Handler decides, no rule | 01 note | GM sets a condition by hand (exists today) | none |

### G8. Armor and damage reduction

**Today:** `derived.json` DR block and `items/armor_vest.json` `drModifier` are `null`.

| Option | Pack | Code |
|---|---|---|
| **A. Flat DR (END + modifier); armor categories light 1-2, medium 3-4, heavy 5+** | `derived.json` DR formula; `items/*.json` `drModifier` | `VitalsSystem` follow-up: damage minus DR suggested in the review tray |
| B. Rolled DR (1d6 + END + armor, older books) | `derived.json` formula with dice | same, rolled at damage time (consumes draws) |

### G9. Weapon MIN and melee Strength

**Today:** `damage.json` `min` is pending where unclear.

| Option | Pack | Code |
|---|---|---|
| **A. MIN = lowest damage a hit does; STR does not add** | `damage.json` `min` values, `meleeAddsStr: false` | damage suggestion floors at `min` |
| B. STR adds to melee | `meleeAddsStr: true` | damage formula adds `attr(STR)` |

### G10. Action economy, Aim, Dodge

**Today:** no `CombatSystem` (01 lists it); `ranges.json` and `items/pistol_cat_d.json` mark G10.

| Option | Spec | Code | Pack |
|---|---|---|---|
| **A. One Major + one Minor per turn; Aim is a Minor action for +1; Dodge against any attack, Parry only melee** | 01 §Systems `CombatSystem` | New row (combat): turn and action tracking; Aim as a labelled modifier | new `combat.json` (`actionsPerTurn`, `aim`), or a `ranges.json` block; field names Proposed |
| B. D's numbers | same | same | same |

### G11. Enemy numbers

**Today:** `threats.json` has Health, DR, damage and sanity cost; `npcs/cult_footsoldier.json` `attributes` is `null`.

| Option | Pack | Code |
|---|---|---|
| **A. Add defense and attack bonus per class, from the class's listed skill bonus** | `threats.json` `defense`, `attack` per class; NPC template attributes | parser `engine/pack/files/threats.dart`; NPC spawn uses them |
| B. D supplies numbers | same | same |

### G13. Old difficulty names

| Option | Pack | Code |
|---|---|---|
| **A. Drop "Tough DC 9", "Moderate", "Advanced", "Extreme 21"; restate each use as a category (crash test, Withdraw as Cat-D or Cat-C; passenger penalties as modifiers)** | `vehicles.json` uses; `difficulty.json` `openItems` | none (data) |
| B. Keep a legacy name table | `difficulty.json` alias table | loader resolves aliases |

### G14. Advancement purchases

| Option | Pack | Code |
|---|---|---|
| **A. "Single use" = once per character; Artifact Clearance is a GM-tracked note** | `advancement.json` `limit: "perCharacter"` | `CharacterSystem` advancement purchase (not built) refuses a second purchase |
| B. Once per purchase | `limit: "perPurchase"` | none |

### G19. Creation totals

**Today:** `CharacterSystem` checks each attribute's 1 to 3 range only (`AttributeCreation.points` is loaded but unused; `ProficiencyCreation.counts` likewise).

| Option | Code | Pack |
|---|---|---|
| **A. Exactly 20 points and exactly 3 Proficient + 1 Expert** | `CharacterSystem` creation check (`engine/systems/character_system.dart`, the `limits` loop): sum equals `points`; skill tier counts equal `counts`; new refusal messages; tests | `attributes.json` `creation.total: "exact"`, `proficiency.json` `creation.mode: "exact"` (field names Proposed) |
| B. At most | same, `<=` | `"atMost"` |

### C1. Content cut since 1.3.1

**Decides:** D. The critical injury table, backlash, artifact repository, forms and personnel are in 1.3.1 and not in the current book. **Assumption:** nothing is restored unless D says so; anything restored is copied from the PC rulebook copy (via the PC session), never reconstructed. Changes land in the pack (new files) and, for rules, in the cards above (G7 for injuries).

---

## Operations and missions (X0)

Source for all: library `architecture/supplemental-x0-pending.md`; 11 §Terminology, §Waiting on X0.

### X0. Which unit owns the event log (Q24)

**Decides:** R and D. **Today:** the spec gives each operation (read as one session) its own event log, RTDB tree, sembast file, archive and migration. R's terms make an operation the whole campaign.

| Option | Spec | Code | Firebase |
|---|---|---|---|
| **A. One log per operation, stored in mission segments** | Glossary rename (README, 11 §Terminology "rename pending"); 01 §Commands and events: `MissionStarted` / `MissionCompleted`; 04 §Interfaces: one sembast file per mission segment (amends 09-3); 05 §What gets migrated; 06 §Realtime Database model (prune `events`/`textlog` per segment; `phone`/`requests` pruning rule); 06 §Cloud Functions: `archiveMission` (amends P14); 12 §Archives and `missions.eventRange` (unit = segment) | `OperationSystem` (`engine/systems/operation_system.dart`) gains mission events (row 1 follow-up); `EventStore` segment files (row 12); host starts a segment from the head snapshot (row 7 follow-up); codecs (row 6) | `firebase/database.rules.json` segment pruning; emulator checks; `archiveMission` function |
| B. One log per mission, carry-over copied | Glossary shift; new "carry-over" section in 05 or 04; 12 `missions` | carry-over step between logs (new row); between-mission activity has no log | per-mission tree |
| C. One unsegmented log per operation | Glossary rename only | none now; log growth unbounded | none |

Also decided by this card:

- **P17 phone-box clearing:** "the mission ends" maps to `MissionCompleted` under A, to the end of the log under B, and has no natural point under C. The clearing mechanism itself is ruled (a function clears the box after the archive).
- **Character carry-over** (inventory, skills, contacts, `KnownAs` from N1): state under A; part of the copy under B.
- **GM notes (decision 13):** per operation under A (one notes document, R's leaning); per mission under B.
- 12 §Held items: archive layout per mission, genesis `archives` fields, alias state between missions, public profile lists.

**Assumption:** A.

### Q5. Requests between sittings

**Decides:** R. Needs X0. **Assumption:** under A, purchases and contact releases queue as ordinary requests under the operation until the Handler's client is online; purchases do not auto-confirm (auto-confirm would extend F2, which covers consequence events only). **Changes:** 04 §Offline and sync semantics; 06 RTDB `requests` (already exists); if auto-confirm is chosen, F2 amendment in 01 and 04 and an `OperationSettings` flag.

### Q7. Messages between sessions

**Decides:** R. Needs X0. **Assumption:** under A, the operation's phone box in RTDB, as designed (P17). **Changes:** none beyond X0's pruning rule.

### Q9. Published mission content

**Decides:** R. Needs X0 and N1. **Assumption:** the debrief forms plus the `public` text log of that segment, never GM or alias branches; the mission id is generated on `MissionStarted`, independent of the operation id (which changes on migration, P12). **Changes:** 11 §Library and public content; 12 `missions/{missionId}` and a library mission kind (12 §Held). The `public` text is only safe to publish after N1's name rule.

### Q33. Anonymous accounts browsing

**Decides:** R and D. **Already ruled (R, 2026-10-21):** no voice, video or messaging for clearance 0. **Assumption:** they join and play, but cannot browse the glossary, bestiary, item catalog or mission library. **Changes:** 11 §Clearance tiers; 12 §Security rules: library read rules require a non-anonymous token (`libraryPublic`, `libraryData`); emulator checks. Under the other option, level-1 content is readable by tier 0 and the rules check `tier() >= 0`.

### Q6. Currency

**Decides:** D. **Provisional (R):** D defines name, prices, starting funds and income in pack data; the engine gets a generic `Funds` vocabulary. **Assumption:** confirm. **Changes:** new pack file `currency.json` (name, starting funds, income) and `price` on `items/*.json` (names Proposed); new `Funds` component and transfer command/event (new row, wallet), codecs; 11 §Currency becomes Fixed. Movement between missions needs X0.

### Q12. Fake websites

**Decides:** D. **Provisional (R):** Handlers write them, per operation, from block templates; library sharing later with moderation. **Assumption:** confirm. **Changes:** 11 §Fake occult websites becomes Fixed; `SiteRevealed` (Proposed in 11 §Amendments) for unlocks; sharing adds a library kind in 12 later.

---

## Narration

### N1. Narrator lines and name reveals

**Decides:** D (D1-D7), R (R1-R5, decision 15). **Source:** library `architecture/narrator-lines-and-name-reveals.md`; `rulebook-gaps.md` N1; `r-questions-4-11-13-15.md` §15.
**Today:** the host narrates every event once with the full state and copies the player line into `public` and each `alias:<id>` (`session/lib/src/operation_host.dart`, `_narrate`); names come from `Identity.name` or the raw id (`engine/narrator/narrator.dart`, `_name`, `_aliases`, `_party`; the `AgentCreated` line reads `event.name`). So a player's stored line can name a GM-only NPC or another player's agent.

**R's side:**

| # | Question | Assumption | Changes |
|---|---|---|---|
| R1 | How lines are produced | (3) Hybrid: clients narrate their live log from their own feed; the host stores per-audience text narrated from that audience's knowledge | Row 7 follow-up: `_narrate` calls the narrator once per audience; participant-side narrator; row 8 follow-up: player and table views narrate the perspective feed instead of `store.readText`, `_breakdown` names from the viewer; 04 §The operation loop, §Perspectives; 03 `textlog` unchanged |
| R2 | Name rule | (a) explicit reveal + fallback, with `RevealName` / `NameRevealed` / `KnownAs` | Row 1 follow-up: command, event, component in `GmSystem` (new system file); narrator takes a `Viewer` and one `nameFor(state, entity, viewer)`; `projectFor` case for multi-alias reveals (`session/lib/src/perspective.dart`); codecs (row 6); migration fixture for `KnownAs`; 01 §Components, §Commands and events |
| R3 | Keep per-batch `textlog` relay (P12 amendment)? | Raised once; R's ruling (keep) stands unless R changes it | (a) keep: none; (b) drop: 06 §Realtime Database model `textlog` branch, row 15 |
| R4 | Fix per-audience narration now, before D rules | Now | Row 7 follow-up, with a placeholder fallback swapped when D1 is ruled |
| R5 | Reveals through the review gate? | Not gated | none (not a `Consequence`) |

**D's side:**

| # | Question | Assumption | Changes |
|---|---|---|---|
| D1 | Name before a reveal | (c) GM-typed description, with (b) numbered unknowns as the fallback | `fallback()` in the narrator; (b) needs a per-viewer numbering map (host per audience, participant per feed); wording in `strings/en.json` |
| D2 | Cover names | Yes | none beyond R2 (`knownAs` is a free label) |
| D3 | Reveal to some agents only | Yes | `RevealName.to` accepts `AliasesOnly` |
| D4 | Earlier lines change after a reveal? | No | narrate with the state at each `seq` (default); (b) would re-render live lines only, stored text cannot change |
| D5 | Agents know each other from the start | By default, with a GM option per agent | public `NameRevealed` at `CreateAgent` unless the GM opts out (`CharacterSystem`, `character_system.dart` visibility stays owner-only for the sheet) |
| D6 | Unknown texter on the phone | "Unknown number" until the contact is released; GM can set a label | `_party` through `nameFor`; ties to `ContactRevealed` (11 §Amendments) |
| D7 | Take a reveal back | No, only a new label going forward | (b) would add a hide event in `GmSystem` |

Key test for all options: for every perspective, the host's stored variant for each `seq` equals what a participant on that perspective narrates from its own feed.

---

## Feature plan items

### F1. Mission library seed cases

**Decides:** D. Existing closed cases from the lore and playtests, and the playtest players' consent. **Assumption:** none seeded until D lists them. **Changes:** library entries through moderation (12 §Library); no code.

### F2. Sign-in code symbology

**Decides:** D. Whether the short-lived sign-in code is also PDF417 like the public badge. **Assumption:** none yet; the sign-in function (P14) mints a value, and the symbology is a rendering choice in the companion and desktop UI. **Changes:** 11 §Sign-in code; the badge package proposal to R (11 §New dependencies) covers both symbologies.
