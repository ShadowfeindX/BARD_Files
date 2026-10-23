# 10. Pending D: post-meeting decision kit

Status: **D answered on 2026-10-22** (the filled-in sheet is [10-pending-d-responses.md](10-pending-d-responses.md)). Each card below carries a **Ruled (D, 2026-10-22)** block with the edits to apply; cards without one still wait. D's follow-up questions are on [10-pending-d-followup.md](10-pending-d-followup.md); R's items are in [R-only items](#r-only-items). Rulings on game content are D's; R approves the PR and every implementation. The text of each card under its Ruled block is the original proposal, kept for reference. It lists everything that has to be handled after the meeting, one card per decision, so that a ruling becomes a small, mechanical edit.

Every card has the same parts (plus a **Ruled** block once D has answered):

- **Decides:** D, R, or R and D. **Source:** where the question and its evidence are.
- **Today:** what `main` already does about it (usually: the value is `null`, the feature is off).
- **Options:** one row per option, with the exact spec sections, code (implementation-plan row and file) and pack files that change if R and D pick it.
- **Assumption:** the option the rest of the work is prepared for. It is the coordinator's existing recommendation, **not a ruling**. Nothing is built on an assumption: the pack keeps `null` and the feature stays off until the ruling (CLAUDE.md §9).

Conventions:

- Spec chapters are cited as `01 §Heading` (this folder). Code paths are relative to the repository root; `engine/` is `packages/engine/lib/src/`. Line numbers are on `main` at the time of writing and drift; the symbol name is the stable reference.
- "Row N" is a workstream in the project library's `architecture/implementation-plan.md`. "Row N follow-up" means a new branch on top of what row N merged. "New row" means work the plan does not have yet.
- **Pack** means the provisional pack `packages/content_core/assets/example-core/` (the authoring source; `tool/build_pack.sh` regenerates the shipped copy). The library copy `packs/example-core/` gets the same edit until D's pack replaces both.
- "Pending" in the pack: the authoring source marks an open value with a placeholder object (`placeholder`, `gap`, `note`); the annotation stripper turns it into `null` in the generated pack, which the loader lists in `RulesPack.pendingPaths`. "Replace the placeholder" below means: write the value in the source, then rebuild.
- An **Assumption** with "(no source; coordinator default)" has no recommendation in the library; the others cite theirs.
- Rulebook pages are PDF pages of `BARD Core Rulebook.pdf`; "1.3.1" is the older reference book. Plain-language versions of the D questions are in the meeting packet (project library `meeting/`).

D's answers are in [10-pending-d-responses.md](10-pending-d-responses.md) (each block carries a card id). New questions that D's answers raised are on [10-pending-d-followup.md](10-pending-d-followup.md) in the same format.

## How to apply a ruling

1. Write the ruling into the **Ruled** column of the [index](#index) (date and R's or D's words), and add a row to the [09 decisions record](09-open-decisions.md#decisions-record-ruled-by-r-2026-10-20).
2. Do the edits listed under the chosen option, on a branch named for the work (`feature/`, `bugfix/` or `docs/`), with the developer guide and `CHANGELOG.md` in the same PR (CLAUDE.md §10).
3. For a pack value: replace the placeholder object in the pack source, run `bash tool/build_pack.sh`, and check that the path left `RulesPack.pendingPaths` (`engine/pack/rules_pack.dart`). If the ruling adds a field, the parser in `engine/pack/files/` and the pack loader tests change with it.
4. Delete the card from this chapter, or shorten it to "Ruled, see 09". Remove the gap from the library's `rulebook/rulebook-gaps.md` and from the pack's `openItems`.
5. If D picks something no option here covers, the card is re-planned before any code, and the plan goes to R.

## Index

| # | Question (short) | Decides | Assumption | Ruled |
|---|---|---|---|---|
| [M1](#m1-occult-check-attribute-c5--g6) | Occult check attribute | D (with R) | WIL, or the named skill's attribute | Agree (D, 2026-10-22) |
| [M2](#m2-cast-magic-and-the-occult-system-f3-part-1) | "Cast magic" as one roll; how much of `OccultSystem` stays | D | One roll, GM-set DC; ritual parts GM-described | Agree (+ DC note) (D, 2026-10-22) |
| [M3](#m3-casting-details-g6) | Sanity timing, group cost, focus category, prerequisite | D | Every cast; half each, rounded up; spell's category; warning only | Changed (a, b, d); c held, FD-M2 (D, 2026-10-22) |
| [P1](#p1-pack-shape-p3) | Pack files and fields | D | Example pack shape as is | Agree (D, 2026-10-22) |
| [P2](#p2-skill-list-g15) | Mind Shielding, three missing attributes, paired skills | D | Add it; INT, INT, WIS; keep pairs | Agree (D, 2026-10-22) |
| [W1](#w1-web-hosting) | Web GM hosting for onboarding | D | Stay player-only | Agree (D, 2026-10-22) |
| [C7](#c7-physical-dice-concern-7) | Physical dice | D | Approve, built after the demo | Agree (D, 2026-10-22) |
| [G1](#g1-fumble) | Fumble basis | D | Total, rounded down | Agree (D, 2026-10-22) |
| [G2](#g2-advantage-and-disadvantage) | Advantage and disadvantage | D | GM grants; disadvantage keeps worst | Agree, superseded by FB1 (D, 2026-10-22) |
| [G3](#g3-which-dice-explode) | Which dice explode | D | Primary d6 and damage dice only | Agree (D, 2026-10-22) |
| [G4](#g4-and-g18-assistance) | Assistance cap and helper bonus (with G18) | D | Cap 3; helper adds own proficiency die | Changed (D, 2026-10-22) |
| [G5](#g5-sanity-loss) | Sanity amounts, resist DC, rounding, disorder roll | D | Roll in range; DC by category; round up; d6 on fail | Changed (D, 2026-10-22) |
| [G7](#g7-dying-and-critical-injury) | Death and critical injury | D | 1.3.1 death rule; optional injury table | Changed (D, 2026-10-22) |
| [G8](#g8-armor-and-damage-reduction) | Armor values and DR | D | Flat DR; light 1-2, medium 3-4, heavy 5+ | Later (D, 2026-10-22) |
| [G9](#g9-weapon-min-and-melee-strength) | Weapon MIN; STR in melee | D | MIN = lowest damage; no STR | Changed (D, 2026-10-22) |
| [G10](#g10-action-economy-aim-dodge) | Actions per turn, Aim, Dodge | D | 1 Major + 1 Minor; Aim Minor +1; Dodge any, Parry melee | Changed (counts); Aim, Dodge open (D, 2026-10-22) |
| [G11](#g11-enemy-numbers) | Enemy defense, attack, speed | D | Defense and attack from the class skill bonus | Later (D, 2026-10-22) |
| [G13](#g13-old-difficulty-names) | Old difficulty names | D | Drop; restate as categories | Agree (D, 2026-10-22) |
| [G14](#g14-advancement-purchases) | "Single use"; Artifact Clearance | D | Once per character; GM-tracked note | Later (D, 2026-10-22) |
| [G19](#g19-creation-totals) | Exact or at most 20 points / 3+1 skills | D | Exact | Changed (D, 2026-10-22) |
| [C1](#c1-content-cut-since-131) | Was content cut since 1.3.1 on purpose? | D | None restored without D | Leave out (D, 2026-10-22) |
| [X0](#x0-which-unit-owns-the-event-log-q24) | Which unit owns the event log (Q24) | R and D | A: one log per operation, mission segments | Changed: Campaign > Operation > Mission > Session (D, 2026-10-22) |
| [Q5](#q5-requests-between-sittings) | Requests between sittings; auto-confirm purchases | R | Queue under the operation; no auto-confirm | Open: R ([R-only items](#r-only-items)) |
| [Q7](#q7-messages-between-sessions) | Where messages between sessions live | R | The operation's phone box | Open: R ([R-only items](#r-only-items)) |
| [Q9](#q9-published-mission-content) | Published mission content and id | R | Debriefs + public text log; id from `MissionStarted` | Open: R ([R-only items](#r-only-items)) |
| [Q33](#q33-anonymous-accounts-browsing) | Anonymous accounts browsing the library | R and D | Play yes, browsing no | No: tier 0 may browse free entries (D, 2026-10-22) |
| [Q6](#q6-currency) | Currency | D | Pack data + generic `Funds` | Later (D, 2026-10-22) |
| [Q12](#q12-fake-websites) | Fake websites: authors, sharing | D | Handlers, per operation; library later | Later, not v1 (D, 2026-10-22) |
| [N1](#n1-narrator-lines-and-name-reveals) | Name reveals (D1-D7) and how lines are produced (R1-R5, decision 15) | D and R | Hybrid + `RevealName` | D1-D3, D5-D7 Agree; D4 Changed; R1-R5 open (D, 2026-10-22) |
| [F1](#f1-mission-library-seed-cases) | Seed cases for the mission library | D | None until D lists them | Players yes; cases open (D, 2026-10-22) |
| [F2](#f2-sign-in-code-symbology) | Sign-in code as PDF417 | D | No assumption; rendering choice only | No (D, 2026-10-22) |
| [K1](#k1-rounding-convention) | Rounding always favours the player | D | Ruled | Ruled (D, 2026-10-22) |
| [K2](#k2-roll-means-the-total) | "Roll" means the total | D | Ruled | Ruled (D, 2026-10-22) |
| [FB1](#fb1-flashback-replaces-advantage-and-disadvantage) | Flashback replaces advantage and disadvantage | D | None | Idea; details open (FD-F1 to FD-F5) |
| [HA1](#ha1-human-adversaries-use-gear-like-players) | Human adversaries use gear like players | D | None | Direction only |
| [UI1](#ui1-reminders-and-tooltips-for-handler-features) | Handler reminders and tooltips | D, R | None | Idea for R |

Not in this chapter: R's own open questions that do not wait on the meeting (decisions 4, 11 and 14 of 2026-10-21, answered in the library's `architecture/r-questions-4-11-13-15.md`), and decision 13 (GM notes) except its "per operation or per mission" part, which is under [X0](#x0-which-unit-owns-the-event-log-q24). Payments stay deferred (concern 6).

---

## Magic

### M1. Occult check attribute (C5 / G6)

**Ruled (D, 2026-10-22): Agree.** WIL by default, or the attribute of the skill the player names (options A with D).
**Apply:** 01 §Rulebook gaps item 5 becomes settled; `occult.json` `castMagic.chosenAttribute` replaces its placeholder with `"skill"` and `fallback: "WIL"` (shape Proposed); `skills.json` sets the occult skills' `attribute` from the dossier grouping; the cast roll in M2 uses it. No other code.

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

**Assumption:** A with D: WIL by default, or the attribute of the skill the player names (coverage report decision 2). The value replaces the existing `castMagic.chosenAttribute` placeholder; the value shapes above (list, `"skill"`, `fallback`) are Proposed.

### M2. Cast magic and the occult system (F3 part 1)

**Ruled (D, 2026-10-22): Agree, option A,** with a note: the Handler sets the DC from the circumstances of the situation; everything (time, helpers, focus items, circumstances) is folded into the final DC the player rolls against.
**Apply:** `OccultSystem` is replaced by one "cast magic" roll (01 §Systems); the Handler types the final DC (a labelled factor list helps, FD-M3); `ritualDefaults` stays in `occult.json` only as Handler guidance (tooltips, UI1), not as engine rules; no participant sub-checks and no focus-item bonus die in the engine. Code: new occult row as in option A.

**Decides:** D. **Source:** 09 F3; rulings log 2026-10-20 (F3 part 1 deferred); coverage report decision 20.
**Today:** no `OccultSystem` in code (01 lists it as Provisional). Spells have no schema (R's game-rules model, 2026-10-16). Sanity loss is GM-entered and goes through the review gate (F2).

| Option | Spec | Code | Pack |
|---|---|---|---|
| **A. One roll kind, GM-set DC; ritual time, participants, focus items are GM-described** | 01 §Systems: `OccultSystem` row shrinks to "cast magic"; 01 §Commands and events: Proposed `CastMagic` command or a `RequireCheck` kind; 02 §Pack structure: `occult.json` fields | New row (occult, Opus-Engine): either a `kind: castMagic` on `RequireCheck` (`engine/commands/check_commands.dart`) or a new command in `CheckSystem`; sanity cost is suggested from `sanityCostByCategory` and entered through `VitalsSystem` like any loss; parser `engine/pack/files/occult.dart` (new); loader stops treating the file as pending; codecs (row 6: `protocol/lib/src/command_codec.dart`, fixtures); narrator case | `occult.json`: keep `rollKindProposal`, `rollFormula`, `sanityCostByCategory`; drop `ritualDefaults` |
| B. As A, with ritual parts as optional defaults the GM can apply | as A, plus 01 note on defaults | as A, plus modifiers the GM can add from `ritualDefaults` (participant +1 each, focus +1d6) as labelled `CheckModifier`s; ritual time is text only | keep `ritualDefaults`; `focusItem.bonus.explode` waits on G3 |
| C. Full `OccultSystem` (occult action checks, rituals, participants, focus items as rules) | 01 §Systems as written today | as B, plus participant checks (DC 10) as sub-checks and a focus-item component (`engine/components/components.dart`) | as B, plus focus items in `items/` |

**Assumption:** A (coverage report decision 20). B is a cheap extension if D wants the p29 numbers to hand.

### M3. Casting details (G6)

**Ruled (D, 2026-10-22):**
- **a. Changed:** the Handler decides when a sanity check is needed (for example when casting against a supernatural entity); the default is **on success only**. Apply: `occult.json` `sanityCheckOn: "success"`; the cast carries a Handler flag that requires the check on any cast.
- **b. Changed:** every player present at the ritual pays sanity on a **success**, whether or not they cast; on a **fail** only the players taking part in the cast pay. Sanity cost is the result of the effect going off, not a cost of the magic ("people go crazy when they see a demon appear, whoever summoned it"). This replaces "each caster pays half". Apply: `groupCost` removed; `occult.json` `sanityPayers: {onSuccess: "present", onFail: "participants"}` (shape Proposed); the cast records who is present and who takes part (Handler selects, FD-M1); amounts are suggested per payer through the review tray (G5).
- **c. Not applied (contradiction, FD-M2):** the box says Agree (the spell's category) but the notes say a better focus item *reduces* the sanity cost and that its category follows relevance to the player, not value. That is not the p29 rule (+2 per category above D). Held until D states the rule.
- **d. Changed:** casting normally needs skill, training, knowledge or guidance; high-affinity individuals (high WIL, related skills, Handler discretion) may cast under extreme circumstances or spontaneously. Apply: a missing prerequisite is refused unless the Handler allows it on that cast (`RejectionCode` in `engine/decision.dart`, Proposed name `missingOccultTraining`, with a Handler allowance flag); no numeric affinity threshold (FD-M4).

**Decides:** D. **Source:** `rulebook-gaps.md` G6; coverage report decision 15; the `occult.json` `sanityCheckOptions` placeholder. Only needed if M2 is A or B.

| Detail | Options | Changes | Assumption |
|---|---|---|---|
| Sanity check timing | (a) every cast (p30 step 5); (b) only on success (1.3.1) | `occult.json` `sanityCheckOn: "everyCast" \| "success"`; the cast's follow-up suggestion in the new occult code | (a) |
| Group casting cost | (a) each caster pays half, rounded up (1.3.1); (b) caster pays all; (c) each pays full | `occult.json` `groupCost`; suggestion per participant in the review tray (row 8 follow-up) | (a) |
| Focus item category | (a) the spell's category; (b) the item's | `occult.json` `focusItem.categoryFrom: "spell" \| "item"` | (a) |
| Arcane proficiency prerequisite | (a) warning the GM can override; (b) hard refusal | (a) a warning on the pending check; (b) a `RejectionCode` in `engine/decision.dart` and its codec | (a) |

The coverage report's reading of the book, not rulings.

---

## Content pack

### P1. Pack shape (P3)

**Ruled (D, 2026-10-22): Agree.** The example pack's file layout stays; no renames.
**Apply:** 02 §Pack structure file list becomes Fixed; `docs/developer-guide/packs.md` drops "provisional shape". Files and fields that other rulings add (creation profiles G19, combat defaults G10, assistance G4) are additive.

**Decides:** D. **Source:** 09 P3; library `packs/example-core/README.md` (tour with layout questions).
**Already fixed:** JSON + manifest; one validator; unknown keys are errors in shipped packs; annotations stripped (`_`-prefixed keys too); `null` is the single pending-D marker; the `var` node; skill = name, description, category, attribute, proficiency; operation-scoped packs.
**Today:** the loader (row 4, merged) reads the provisional shape, one parser per file in `engine/pack/files/`.

| Option | Spec | Code | Pack |
|---|---|---|---|
| **A. Keep the example shape** | 02 §Pack structure: file list becomes Fixed; 09 P3 row | none; developer guide `docs/developer-guide/packs.md` drops "Provisional" | none |
| B. Rename, merge or drop named fields or files | 02 §Pack structure | per renamed file: its parser in `engine/pack/files/`, the file list `packFiles` in `pack_loader.dart`, `RulesPack` fields, loader tests; renames inside a major follow 02 §Deprecation in packs (additive + deprecation) | the named files, in both copies |
| C. D supplies a new pack | 02 §Pack structure | as B, file by file | replace `example-core/` in `content_core`; README of `content_core` |

The `difficulty.json` `checkRules` block sits there as a proposal (`_shapeNote`); D and R may move it. The library provenance field must not reuse the stripped `source` key.

**Assumption:** A, with D's renames applied as B (no source; coordinator default: the library only asks D to review the example).

### P2. Skill list (G15)

**Ruled (D, 2026-10-22): Agree.**
**Apply:** `skills.json` adds Eldritch Lore (INT) and Vehicle Modification (INT), sets Insight to WIS, keeps Mind Shielding (WIL) and the paired skills separate; categories come from the p19 skill list (PC extraction, never reconstructed); remove the G15 `openItems` entry; no code.

**Decides:** D. **Source:** `rulebook-gaps.md` G15.
**Today:** `skills.json` already has Mind Shielding (`mind_shielding`, WIL, from the dossier) and Insight with a placeholder attribute; Eldritch Lore and Vehicle Modification are not in the file. A check on a skill with no attribute is refused until the GM names one (`CheckSystem._spec`, "pending D").

| Option | Changes | |
|---|---|---|
| **Keep Mind Shielding (WIL); add Eldritch Lore (INT) and Vehicle Modification (INT); Insight WIS (2.1); keep paired skills separate** | `skills.json`: two new skills, Insight's attribute; remove the G15 `openItems` entry; no code | **Assumption** (`rulebook-gaps.md` G15) |
| Other attributes | same file | |
| Drop Mind Shielding | remove it from `skills.json`; M1 option D loses one WIL skill | |
| Merge Alchemy / Advanced Alchemy or Explosive Disposal / Explosives | `skills.json`; deprecation records if the pack has shipped (02 §Deprecation in packs) | |

---

## Platform and features

### W1. Web hosting

**Ruled (D, 2026-10-22): Agree.** The web build stays player-only.
**Apply:** 09 W1 row becomes "confirmed with D"; 07 §Web build role drops "Revisiting W1 is Pending D"; no code.

**Decides:** D. **Source:** 09 W1; 07 §Web build role.
**Today:** the web build is player-only. 07 §Web build role specifies hosting modes read from a per-platform capability set (for example `canHost`, `canEditPacks`), so a change is configuration; the capability set is not built yet (no code on `main`).

| Option | Spec | Code |
|---|---|---|
| **A. Stay player-only** | 09 W1 row: drop "for now" and "Revisit with D" | none |
| B. Web GM limited to RTDB relay and P2P (no LAN) | 07 §Web build role; 04 §Play modes (web host row); 09 W1, concern 2; P12 web-host autosave (no sembast file: RTDB head only) | build the capability set in `apps/bard` (row 8 follow-up); `sembast_web` host store (row 12 follow-up); relay (row 15) |

**Assumption:** A, R's current ruling (R's reason: a web GM loses control over engine version, pack choice and modifying their own games). B only if D needs it for onboarding.

### C7. Physical dice (concern 7)

**Ruled (D, 2026-10-22): Agree.** Approved for the game, built after the demo; typed-in faces are never re-rolled or changed.
**Apply:** option A edits (01, 04, 03; `ResolveCheck` faces; `OperationSettings.allowPhysicalDice`, default `false`; GM entry UI; `ui_kit` marking). R schedules the row. Which unit owns the setting (campaign, operation, mission or session) follows X0 (FD-X1).

**Decides:** D. **Source:** 09 concern 7.
**Today:** `CheckResolved` carries `source` (`rng` | `entered`) and `enteredBy` (`engine/events/check_events.dart`); only `rng` is produced.

| Option | Spec | Code |
|---|---|---|
| **A. Approve** | 01 §Commands and events: entered faces; 04 §Play modes; 03 §Message bodies (faces on the request); 09 concern 7 | Row 5 follow-up: `ResolveCheck` takes optional `faces`, validated against the dice the check would roll, refused unless the operation allows it; `OperationSettings` (`engine/state/operation_state.dart`) gains `allowPhysicalDice` (default `false`) and its codec (`protocol/lib/src/shared_codec.dart`); player request carries faces (row 7); GM setting and entry UI (row 8 follow-up); `ui_kit` dice breakdown marks entered faces |
| B. Keep out of v1 | 09 concern 7: "out of v1"; field stays reserved | none |

The design as R specified it: a per-operation GM setting, off by default and agreed with the players; entered faces are recorded with `source: entered` and who entered them. Proposed, not ruled: entered faces, like app rolls, are never re-rolled or altered (F2).

**Assumption:** A (no source; coordinator default: R specified the design and the field is reserved). Not in the demo slice (implementation plan).

---

## Rulebook gaps

Values D has not given. The engine can represent each variant; agents never choose (CLAUDE.md §9). Source for all: library `rulebook/rulebook-gaps.md` and the coverage report. Each card's **Assumption** is the "possible answer" in that file.

### G1. Fumble

**Ruled (D, 2026-10-22): Agree,** note: "Roll means total in most cases unless otherwise specified" (K2).
**Apply:** option A: total, rounded down. `difficulty.json` `checkRules.fumble.basis: "total"`, `rounding: "down"` (this is also the K1 direction: fewer fumbles favours the player); `CheckOutcome.fumble`, codec, narrator, `ui_kit` label.

**Today:** `CheckRules.fumbleFractionOfDc` is loaded (0.25, `engine/pack/files/difficulty.dart`); `fumble.basis` is a placeholder; `CheckOutcome` has no fumble and fumbles are off (`CheckSystem` doc comment).

| Option | Spec | Code | Pack |
|---|---|---|---|
| **A. Total, rounded down** | 01 §Dice and checks (vocabulary): fumble rule | Row 5 follow-up: `CheckOutcome.fumble` (`engine/checks/check_types.dart`); `CheckSystem._outcome` tests `total <= floor(fraction × dc)` before partial success; codec value and fixture (`protocol/lib/src/event_codec.dart`); narrator line (`engine/narrator/narrator.dart`); `ui_kit` dice breakdown label; parser reads `basis` and `rounding` | `difficulty.json` `checkRules.fumble.basis: "total"`, `rounding: "down"` |
| B. Primary die alone | same | same, comparing the primary die's first face | `basis: "primaryDie"` |

"Immediate complications" on a sanity fumble is G5.

**Assumption:** A (`rulebook-gaps.md` G1, possible answer).

### G2. Advantage and disadvantage

**Ruled (D, 2026-10-22): Agree, then superseded.** D also asked for advantage and disadvantage to be **replaced by flashback** (see [FB1](#fb1-flashback-replaces-advantage-and-disadvantage)). Nothing is built for G2; the `luckAdvantage` block stays pending until FB1 is settled.

**Today:** `luckAdvantage` is loaded (`extraPrimaryDiceFrom: LCK`, `keep: bestTotal`); `grantedBy` is a placeholder; not built.

| Option | Spec | Code | Pack |
|---|---|---|---|
| **A. GM grants it per check; disadvantage = roll the same extra dice and keep the worst** | 01 §Dice and checks (vocabulary) | Row 5 follow-up: `RequireCheck` gains `advantage: none \| advantage \| disadvantage`; roll draws extra primary dice and keeps best or worst total; breakdown shows every set; codec + fixture; GM control (row 8 follow-up) | `difficulty.json` `luckAdvantage.grantedBy: "gm"`, `disadvantageKeep: "worstTotal"` |
| B. D lists triggers | 01 as A, plus a trigger list | as A, plus GM prompts per trigger | `grantedBy` as a list (field shape to plan) |

**Assumption:** A (`rulebook-gaps.md` G2, possible answer).

### G3. Which dice explode

**Ruled (D, 2026-10-22): Agree.** Primary d6 and damage dice explode; not the proficiency die, helper dice (helpers now add a flat score, G4), focus-item die or advantage dice.
**Apply:** option A: `explode: true` on `damage.json` and `threats.json` damage dice; `false` on the proficiency tiers, `advancement.json` dice and the `occult.json` focus die (the occult focus die is removed by M2/M3c anyway); data only.

**Today:** every `explode: null` in the pack means "not ruled"; the evaluator rolls `null` as not exploding (`Dice.explodes` in `engine/expr/expr.dart`). Only the primary die is `true`.

| Option | Pack | Code |
|---|---|---|
| **A. Primary d6 and damage dice; not proficiency, helper, focus or advantage dice** | `damage.json` and `threats.json` damage dice `explode: true`; `proficiency.json`, `advancement.json`, the `difficulty.json` assistance die and the `occult.json` focus die `false` | none (data only); tests for exploding damage |
| B. Every die (p11 first sentence) | all `explode: true` | none |
| C. Primary die only (p11 second sentence) | all others `false` | none |

**Assumption:** A (`rulebook-gaps.md` G3, possible answer).

### G4 and G18. Assistance

**Ruled (D, 2026-10-22): Changed (both parts).**
- **Cap:** the number of helpers on a check equals the score of the attribute the roll uses, plus 1 (STR 3 means up to 4 helpers).
- **Helper bonus:** each helper adds their flat attribute score (4 helpers with STR 3 each add 12). The 1d6 and the proficiency die are gone.
**Apply:** `difficulty.json` `assistance.cap` becomes `{"type": "attributePlus", "plus": 1}` and `assistance.bonus` becomes the helper's own score in the check's attribute (`var` `helperAttribute`; `helperSkillBonus` in `engine/expr/vars.dart` is dropped with a deprecation per P11 if a pack has shipped it); 01 §Dice and checks and 02 §Named variables change the assistance placement; engine: assistance in `CheckSystem` (row 5 follow-up) with refusal `tooManyHelpers` (Proposed) and one breakdown line per helper. Open before building: FD-A1, FD-A2.

**Today:** `assistance` is loaded (gate Cat-D, bonus `1d6 + var(helperSkillBonus)`), `cap` is a placeholder; assistance is not built. `helperSkillBonus` has no defined value since proficiency became dice (G16).

| Part | Options | Spec | Code | Pack |
|---|---|---|---|---|
| Helper bonus (G18) | **(a) helper rolls their own proficiency die: 1d6 + 1d4 Proficient, 1d6 + 1d6 Expert, 1d6 untrained**; (b) a flat number D gives | 01 §Dice and checks (vocabulary); 02 §Named variables (the `var` placement changes) | New: assistance in `CheckSystem` (row 5 follow-up): helper's gate check, then the bonus; for (a) the `helperSkillBonus` var is replaced by the helper's tier expression, so `engine/expr/vars.dart` drops it (deprecation per 01 §Deprecation if any pack shipped it) | (a) `difficulty.json` `assistance.bonus` becomes `1d6` + `{"type":"helperProficiency"}` (new node, Proposed) or the loader adds the tier die; (b) keep the `var` |
| Cap (G4) | **(a) 3 helpers on ordinary checks**; (b) no cap; (c) another number | 01 §Dice and checks (vocabulary) | refusal code `tooManyHelpers` (Proposed) | `assistance.cap: 3`, or `"none"` for no cap |
| Ritual helpers (p29) | keep as written (DC 10, +1 each) | M2 | M2 option B or C | `occult.json` |

**Assumption:** (a) and (a). Assistance stays off until both are ruled.

### G5. Sanity loss

**Ruled (D, 2026-10-22): Changed.** Sanity loss for events and disorders gets reworked.
- **a.** The Handler sets the loss; the ranges are suggested values only (no automatic roll).
- **b.** The DC to resist is set by current Sanity: at 20, 40, 60, 80 and 100% of maximum Sanity the check is Cat-S, A, B, C and D (at 20% it is Cat-S, DC 21).
- **c.** Half loss rounds **down**: "when rounding in B.A.R.D. we ALWAYS round to the benefit of the player" (K1).
- **d.** Anomalous attacks: a partial success halves the loss, or the Handler sets a narrative effect.
- **e.** Fumbling the resist roll: full loss plus 1; the Handler describes the complication. **f.** A failed disorder check rolls 1d6 on the disorder table.
**Apply:** `sanity_events.json` ranges become suggestions (`pick: "gm"`), `resistDc.bands` (20 to S, 40 to A, 60 to B, 80 to C, 100 to D; boundary inclusivity assumed, FD-S1), `halfRounding: "down"`, `fumbleExtra: 1`; `disorders.json` `rollDie: {"type":"dice","count":1,"sides":6}`; 01 §Systems `VitalsSystem` and `ConditionSystem` rows; no automatic sanity roll in the engine. D will supply the reworked tables (FD-S3); until then the book's ranges stay as suggestions.

**Today:** the GM enters every sanity amount through `VitalsSystem`, and the session holds it for review (F2, `session/lib/src/operation_host.dart`). `sanity_events.json` has ranges with placeholders; `disorders.json` `rollDie` is `null` (a pending value in the source too).

| Part | Assumption | Other options | Code | Pack |
|---|---|---|---|---|
| Amount in a range | Rolled within the range; GM can override before broadcast (already ruled: sanity loss hard-coded, GM override) | GM picks; midpoint | `VitalsSystem` follow-up: suggest a rolled amount from the event's range | `sanity_events.json` `pick: "roll"` |
| Resist DC | A default per trauma category | one fixed DC; GM sets | resist check is an ordinary `RequireCheck` | `sanity_events.json` `resistCategory` per event |
| Half loss rounding | Up | down | suggestion arithmetic | `halfRounding: "up"` |
| Anomalous attack damage | Partial success costs half | full | `VitalsSystem` suggestion | `sanity_events.json` or `threats.json` flag |
| Fumble on resist | Full + 1 and a GM-described complication | D's rule | needs G1 | `fumbleExtra: 1` |
| Disorder roll | Failed WIL DC 10 check rolls 1d6 on the table | GM picks | `ConditionSystem` follow-up | `disorders.json` `rollDie: {"type":"dice","count":1,"sides":6}` |

### G7. Dying and critical injury

**Ruled (D, 2026-10-22): Changed.** A character reaching 0 Health dies (the app flashes a death screen). A character at 0 Sanity passes to the Handler's control, very likely ending in a bad narrative event and death. The Handler can kill a character at any time. The Handler chooses the DC and the mechanical effect from a list of automated effects, plus a custom option.
**Apply:** no incapacitated state, no accumulating damage rule and no critical-injury table (C1 leaves the 1.3.1 table out); 01 §Systems `VitalsSystem`; new events `CharacterDied` and `ControlTransferred` and Handler command `KillCharacter` (names Proposed; row 1 follow-up, codecs in row 6); the Handler's effect list is the engine's existing consequence events (damage, sanity loss, condition, modifier) plus a custom text option (D names more, FD-D2); death screen in `ui_kit` and `apps/bard` (row 8 follow-up). Whether death at 0 Health goes through the review gate is R's call (R7).

**Today:** `VitalsSystem` does not clamp; nothing happens at or below 0 (its doc comment).

| Option | Spec | Code | Pack |
|---|---|---|---|
| **A. 1.3.1 death rule (damage past 0 accumulates; more than END = death); six-entry injury table as optional base content; injury check at a real category** | 01 §Systems `VitalsSystem` | New row (vitals rules): incapacitated and dead states as components or conditions; injury check as `RequireCheck`; table roll; review gate applies | new `injuries.json` (or a `damage.json` block): table rows from 1.3.1 (needs a PC extraction, never reconstructed); `criticalInjury.checkCategory` |
| B. D writes a new rule | same | per D | per D |
| C. Handler decides, no rule | 01 note | GM sets a condition by hand (exists today) | none |

**Assumption:** A (`rulebook-gaps.md` G7, possible answer).

### G8. Armor and damage reduction

**Ruled (D, 2026-10-22): Later.** Stays pending; revisit later in v1 development. Pack placeholders stay.

**Today:** `derived.json` `damageReduction` is `attr(END)` with an `armorModifierAdded` placeholder (G8); `items/armor_vest.json` `drModifier` is `null`.

| Option | Pack | Code |
|---|---|---|
| **A. Flat DR (END + modifier); armor categories light 1-2, medium 3-4, heavy 5+** | `derived.json` `damageReduction` adds the armor modifier (replaces `armorModifierAdded`); `items/*.json` `drModifier` | `VitalsSystem` follow-up: damage minus DR suggested in the review tray |
| B. Rolled DR (1d6 + END + armor, older books) | `derived.json` formula with dice | same, rolled at damage time (consumes draws) |

**Assumption:** A (`rulebook-gaps.md` G8, possible answer).

### G9. Weapon MIN and melee Strength

**Ruled (D, 2026-10-22): Changed.** MIN is the lowest total damage a ranged weapon attack can do, including all modifiers. For a melee weapon the lowest total is the weapon's MIN or the flat STR score, whichever is greater.
**Apply:** `damage.json` `min` read as a floor on the **total**; `meleeFloor: "max(min, STR)"` (shape Proposed); Strength is never added to melee damage dice; damage suggestion in the review tray is floored (VitalsSystem follow-up). Weapon MIN values themselves are still `null` where D has not given them.

**Today:** `damage.json` `min` is pending where unclear.

| Option | Pack | Code |
|---|---|---|
| **A. MIN = lowest damage a hit does; STR does not add** | `damage.json` `min` values, `meleeAddsStr: false` | damage suggestion floors at `min` |
| B. STR adds to melee | `meleeAddsStr: true` | damage formula adds `attr(STR)` |

**Assumption:** A (`rulebook-gaps.md` G9, possible answer).

### G10. Action economy, Aim, Dodge

**Ruled (D, 2026-10-22): Changed (counts only).** By default one Major and one Minor action per turn and one reaction (Dodge or Parry) between turns. An item, bonus or skill the Handler grants may increase any of these.
**Apply:** new `combat.json` `actionsPerTurn: {major: 1, minor: 1, reaction: 1}`; a per-entity modifier (Proposed component `ActionBudgetBonus`) for Handler-granted increases; new combat row (01 §Systems `CombatSystem`). Not ruled: Aim and what Dodge and Parry answer (FD-C1), when the reaction refreshes (FD-C2).

**Today:** no `CombatSystem` (01 lists it); `ranges.json` and `items/pistol_cat_d.json` mark G10.

| Option | Spec | Code | Pack |
|---|---|---|---|
| **A. One Major + one Minor per turn; Aim is a Minor action for +1; Dodge against any attack, Parry only melee** | 01 §Systems `CombatSystem` | New row (combat): turn and action tracking; Aim as a labelled modifier | new `combat.json` (`actionsPerTurn`, `aim`), or a `ranges.json` block; field names Proposed |
| B. D's numbers | same | same | same |

**Assumption:** A (`rulebook-gaps.md` G10, possible answer).

### G11. Enemy numbers

**Ruled (D, 2026-10-22): Later.** Plus a direction: human adversaries get their stats from weapons and gear exactly like players (HA1). Class defense and attack numbers wait.

**Today:** `threats.json` has Health, DR, damage and sanity cost; `npcs/cult_footsoldier.json` `attributes` is `null`.

| Option | Pack | Code |
|---|---|---|
| **A. Add defense and attack bonus per class, from the class's listed skill bonus** | `threats.json` `defense`, `attack` per class; NPC template attributes | parser `engine/pack/files/threats.dart`; NPC spawn uses them |
| B. D supplies numbers | same | same |

**Assumption:** A (`rulebook-gaps.md` G11, possible answer).

### G13. Old difficulty names

**Ruled (D, 2026-10-22): Agree.**
**Apply:** option A: drop the old names; restate each use as a category (`vehicles.json`, `difficulty.json` `openItems`); data only.

**Today:** the old names appear only as annotations (`vehicles.json`, `difficulty.json` `openItems`, G13); nothing in code uses them.

| Option | Pack | Code |
|---|---|---|
| **A. Drop "Tough DC 9", "Moderate", "Advanced", "Extreme 21"; restate each use as a category (crash test, Withdraw as Cat-D or Cat-C; passenger penalties as modifiers)** | `vehicles.json` uses; `difficulty.json` `openItems` | none (data) |
| B. Keep a legacy name table | `difficulty.json` alias table | loader resolves aliases |

**Assumption:** A (`rulebook-gaps.md` G13, possible answer).

### G14. Advancement purchases

**Ruled (D, 2026-10-22): Later.** Revisit later in v1 development.

**Today:** `advancement.json` marks the single-use rows and Artifact Clearance with G14 placeholders; advancement purchases are not built.

| Option | Pack | Code |
|---|---|---|
| **A. "Single use" = once per character; Artifact Clearance is a GM-tracked note** | `advancement.json` `limit: "perCharacter"` | `CharacterSystem` advancement purchase (not built) refuses a second purchase |
| B. Once per purchase | `limit: "perPurchase"` | none |

**Assumption:** A (`rulebook-gaps.md` G14, possible answer).

### G19. Creation totals

**Ruled (D, 2026-10-22): Changed.** Limits, not exact totals, and two character kinds:
- **Agent alias or Occult Organization member:** at most 20 attribute points in total; one attribute may be 5, two at most 4. Proficiencies are not mandatory (2 Expert and no Proficient is allowed); at least 1 Expert is mandatory.
- **SKALD (civilian character, not an agent alias):** at most 15 points in total; one attribute at most 4, two at most 3. One Expert and one Proficient at most; neither is mandatory.
**Apply:** pack creation profiles `agent` and `skald` replace the single `AttributeCreation` range and `ProficiencyCreation.counts` (`attributes.json`, `proficiency.json`; names Proposed); `CharacterSystem` creation (`character_system.dart`) takes a profile and checks the total, the per-attribute caps and the skill rules; 11 §Agents, aliases and profiles gains SKALD as a character kind. Not building until FD-G1 to FD-G4 are answered (minimum score, the rest of the attribute caps, how many skills an agent may take).

**Today:** `CharacterSystem` checks each attribute's 1 to 3 range only (`AttributeCreation.points` is loaded but unused; `ProficiencyCreation.counts` likewise).

| Option | Code | Pack |
|---|---|---|
| **A. Exactly 20 points and exactly 3 Proficient + 1 Expert** | `CharacterSystem` creation check (`engine/systems/character_system.dart`, the `limits` loop): sum equals `points`; skill tier counts equal `counts`; new refusal messages; tests | `attributes.json` `creation.total: "exact"`, `proficiency.json` `creation.mode: "exact"` (field names Proposed) |
| B. At most | same, `<=` | `"atMost"` |

**Assumption:** A (`rulebook-gaps.md` G19, possible answer).

### C1. Content cut since 1.3.1

**Ruled (D, 2026-10-22): Leave out.** The critical injury table, backlash, artifact repository, forms and personnel were cut on purpose.
**Apply:** remove them from `rulebook-gaps.md` and the coverage report; nothing is added to the pack; the "File Repository" follow-up is dropped.

**Decides:** D. **Source:** coverage report §9 item 18. The critical injury table, backlash, artifact repository, forms and personnel are in 1.3.1 and not in the current book.

| Option | Changes |
|---|---|
| A. Cut on purpose | none; remove the question from the coverage report |
| B. Cut on purpose, but artifacts and forms move to the File Repository (the report's follow-up) | library content (12 §Library), not the pack |
| C. Restore some (D names them) | copied from the PC rulebook copy (via the PC session), never reconstructed; pack files per item; rules through the cards above (G7 for injuries) |

**Assumption:** A unless D names items (no source; coordinator default).

---

## Operations and missions (X0)

Source for all: library `architecture/supplemental-x0-pending.md`; 11 §Terminology, §Waiting on X0.

### X0. Which unit owns the event log (Q24)

**Ruled (D, 2026-10-22): Changed.** D replaces the model with four levels, **Campaign > Operation > Mission > Session**, and each level is archived:
- **Session:** one unit of play between players (1 to 3 hours on average).
- **Mission:** a scenario or objective the agents try to complete, accomplished across a series of sessions (1 to 3 on average).
- **Operation:** a long-horizon goal, story arc or other collection of missions (1 to 10 on average), managed by a Handler. An operation can have several missions running concurrently but not simultaneously.
- **Campaign:** a series of operations managed by a GM. A campaign can have several operations running concurrently or simultaneously.
- A GM may have more than one handler character, persona or alias, one per operation. A player may have more than one alias in an operation or a mission, and an alias may appear in several missions.

This **supersedes** R's 2026-10-20 terms ("operation = the whole campaign") in 11 §Terminology and the glossary. The options below (A to C) were written for the old terms and are **not** the decision any more; the open design question (which of these units owns an event log, an RTDB tree and a sembast file) is restated for R in R-X0. D's follow-up questions are FD-X1 to FD-X8.
**Apply now (docs only):** README glossary and 11 §Terminology use D's four terms; the spec-wide rename of chapters 01 to 08 and 12 waits on R-X0 (until then those chapters' "operation" means the unit of live play, which in D's terms is a session). Per level, archive and summaries are listed under R-X0.

**Decides:** R and D. **Today:** the spec gives each operation (read as one session) its own event log, RTDB tree, sembast file, archive and migration. R's terms make an operation the whole campaign.

| Option | Spec | Code | Firebase |
|---|---|---|---|
| **A. One log per operation, stored in mission segments** | Glossary rename (README, 11 §Terminology "rename pending"); 01 §Commands and events: `MissionStarted` / `MissionCompleted`; 04 §Interfaces the session depends on: one sembast file per mission segment (amends 09-3); 05 §What gets migrated; 06 §Realtime Database model (prune `events`/`textlog` per segment; `phone`/`requests` pruning rule); 06 §Cloud Functions: `archiveMission` (amends P14); 12 §Archives and `missions.eventRange` (unit = segment) | `OperationSystem` (`engine/systems/operation_system.dart`) gains mission events (row 1 follow-up); `EventStore` segment files (row 12); host starts a segment from the head snapshot (row 7 follow-up); codecs (row 6) | `firebase/database.rules.json` segment pruning; emulator checks; `archiveMission` function |
| B. One log per mission, carry-over copied | Glossary shift; new "carry-over" section in 05 or 04; 12 `missions` | carry-over step between logs (new row); between-mission activity has no log | per-mission tree |
| C. One unsegmented log per operation | Glossary rename only | none now; log growth unbounded | none |

Also decided by this card:

- **P17 phone-box clearing:** "the mission ends" maps to `MissionCompleted` under A, to the end of the log under B, and has no natural point under C. The clearing mechanism itself is ruled (a function clears the box after the archive).
- **Character carry-over** (inventory, skills, contacts, `KnownAs` from N1): state under A; part of the copy under B.
- **GM notes (decision 13), scope only:** the storage shape (one notes document beside the log, not events) is the Opus-Gate recommendation awaiting R; whether notes are per operation, per mission or both is open there. The natural fit is per operation under A and per mission under B.
- 12 §Held and questions for R items: archive layout per mission, genesis `archives` fields, alias state between missions, public profile lists.

**Assumption:** A.

### Q5. Requests between sittings

**Decides:** R. Needs X0. **Source:** `supplemental-x0-pending.md`. **Today:** nothing built. **Assumption:** under A, purchases and contact releases queue as ordinary requests under the operation until the Handler's client is online; purchases do not auto-confirm (auto-confirm would extend F2, which covers consequence events only). **Changes:** 04 §Offline and sync semantics; 06 RTDB `requests` (already exists); if auto-confirm is chosen, F2 amendment in 01 and 04 and an `OperationSettings` flag.

### Q7. Messages between sessions

**Decides:** R. Needs X0. **Source:** `supplemental-x0-pending.md`; 06 RTDB `phone` (P17). **Assumption:** under A, the operation's phone box in RTDB, as designed (P17). **Changes:** none beyond X0's pruning rule.

### Q9. Published mission content

**Decides:** R. Needs X0 and N1. **Source:** `supplemental-x0-pending.md`. **Today:** 12 `missions/{missionId}` holds a summary; `eventRange` unit Proposed. **Assumption:** the debrief forms plus the `public` text log of that segment, never GM or alias branches; the mission id is generated on `MissionStarted`, independent of the operation id (which changes on migration, P12). **Changes:** 11 §Library and public content; 12 `missions/{missionId}` and a library mission kind (12 §Held and questions for R). The `public` text is only safe to publish after N1's name rule.

### Q33. Anonymous accounts browsing

**Ruled (D, 2026-10-22): No.** Anonymous (clearance 0) accounts may join games and may also browse the free entries. They still have no voice, video or messaging (R, 2026-10-21).
**Apply:** 11 §Clearance tiers: tier 0 reads the same free (level-1) entries as tier 1; 12 §Security rules: the library read rules admit anonymous tokens for level-1 entries (and not above); emulator checks added; the "no browsing" line in the supplemental spec is removed. Open: FD-Q1.

**Decides:** R and D. **Source:** `supplemental-x0-pending.md`. **Already ruled (R, 2026-10-21):** no voice, video or messaging for clearance 0. **Assumption:** they join and play, but cannot browse the glossary, bestiary, item catalog or mission library. **Changes:** 11 §Clearance tiers; 12 §Security rules: library read rules require a non-anonymous token (`libraryPublic`, `libraryData`); emulator checks. Under the other option, level-1 content is readable by tier 0 and the rules check `tier() >= 0`.

### Q6. Currency

**Ruled (D, 2026-10-22): Later.** Currency stays provisional (D defines it in pack data later).

**Decides:** D. **Source:** 11 §Currency; `supplemental-x0-pending.md`. **Today:** no `Funds` code, no currency pack file. **Provisional (R):** D defines name, prices, starting funds and income in pack data; the engine gets a generic `Funds` vocabulary. **Assumption:** confirm. **Changes:** new pack file `currency.json` (name, starting funds, income) and `price` on `items/*.json` (names Proposed); new `Funds` component and transfer command/event (new row, wallet), codecs; 11 §Currency becomes Fixed. Movement between missions needs X0.

### Q12. Fake websites

**Ruled (D, 2026-10-22): Later, and not in v1.**
**Apply:** 11 §Fake occult websites is marked post-v1; no `SiteRevealed` work in v1.

**Decides:** D. **Source:** 11 §Fake occult websites; `supplemental-x0-pending.md`. **Today:** nothing built. **Provisional (R):** Handlers write them, per operation, from block templates; library sharing later with moderation. **Assumption:** confirm. **Changes:** 11 §Fake occult websites becomes Fixed; `SiteRevealed` (Proposed in 11 §Amendments) for unlocks; sharing adds a library kind in 12 later.

---

## Narration

### N1. Narrator lines and name reveals

**Ruled (D, 2026-10-22):** D1, D2, D3, D5, D6 and D7 **Agree**. **D4 changed:** after a reveal the log of the **current session** shows the new name on every line; **archived logs do not change**. R1 to R5 (decision 15) are R's and still open.
**Apply:** the D4 row below changes to "re-render the live session's lines with what the viewer knows now"; archived sessions keep their text as archived; A4.4 "Earlier lines" in the library write-up changes accordingly (it said no retroactive change). Technical consequence for R (R6): the host's stored text for the current session is regenerated on a reveal or at session end. Revealed names carry forward as state (FD-N1).

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
| D4 | Earlier lines change after a reveal? | **Ruled (D, 2026-10-22): yes in the current session, no in archived logs** | the live session's lines are re-rendered with what the viewer knows now; sessions already archived keep their text; the host regenerates the current session's stored text on a reveal or at session end (R6) |
| D5 | Agents know each other from the start | By default, with a GM option per agent | public `NameRevealed` at `CreateAgent` unless the GM opts out (`CharacterSystem`, `character_system.dart` visibility stays owner-only for the sheet) |
| D6 | Unknown texter on the phone | "Unknown number" until the contact is released; GM can set a label | `_party` through `nameFor`; ties to `ContactRevealed` (11 §Amendments) |
| D7 | Take a reveal back | No, only a new label going forward | (b) would add a hide event in `GmSystem` |

Key test for all options: for every perspective, the host's stored variant for each `seq` equals what a participant on that perspective narrates from its own feed.

---

## New from D's answers

### K1. Rounding convention

**Ruled (D, 2026-10-22):** "When rounding in B.A.R.D. we ALWAYS round to the benefit of the player." Stated with G5c (half sanity loss rounds down).
**Apply:** 01 gains a "Rounding" paragraph; every place the engine or a pack rounds names its direction (fumble threshold down, half sanity loss down, others as FD-K1 confirms); packs carry the direction beside each fraction (`rounding: "down" | "up"`).

### K2. "Roll" means the total

**Ruled (D, 2026-10-22):** "Roll means total in most cases unless otherwise specified" (stated with G1).
**Apply:** 01 §Dice and checks defines "roll" as the final total unless a rule says "the die"; rule text in packs and the manual follows.

### FB1. Flashback replaces advantage and disadvantage

**Idea (D, 2026-10-22):** replace advantage and disadvantage with **flashback**: a player adds a bonus to a **failed** roll by giving a narrative reason why they would have succeeded, thanks to past preparation.
**Today:** `luckAdvantage` is loaded and unused; G2 is superseded by this.
**Not decided:** the size of the bonus, how often it may be used, who approves the reason, whether it can rescue a fumble, and what happens to Luck's extra dice (FD-F1 to FD-F5). R: a flashback changes a resolved check's outcome, which sits against F2 ("rolled faces are never altered"); it needs an additive, logged event beside the roll (R8).
**Likely edits (not started):** 01 §Dice and checks and §Commands and events (a Proposed `UseFlashback` command and `FlashbackUsed` event, bonus shown beside the original roll); `difficulty.json` `luckAdvantage` replaced; narrator and `ui_kit` breakdown; 03 codecs.

### HA1. Human adversaries use gear like players

**Direction (D, 2026-10-22):** human adversaries get their stats from weapons and gear in the same way as players.
**Effect:** G11 (Later) shrinks to the supernatural classes; human NPC templates use attributes, skills and `items/` like a player alias (FD-H1). **Apply:** none yet; 02 §Content kinds notes it when G11 is ruled.

### UI1. Reminders and tooltips for Handler features

**Idea (D, 2026-10-22):** pop-up reminders and tooltips for Handler features and abstract rulings. D's feature ideas go through R. **Today:** `ui_kit` has no tooltip layer. **Likely edits (not started):** a Handler-hint component in `ui_kit` and hint text in the pack's `strings/` (editable by R and D without Dart); the first list of hints is D's (FD-T1). Natural home for the `ritualDefaults` guidance (M2) and the sanity suggestions (G5).

### Revisit later in v1 development

G8 (armor), G11 (enemy numbers) and G14 (advancement) are flagged by D to come back to later in v1; Q6 (currency) and Q12 (fake websites, not v1) likewise.

## R-only items

D's answers leave these for R. Defaults are assumptions, not rulings.

| # | Item | Assumption | Edits if taken |
|---|---|---|---|
| R-X0 | Which of Campaign, Operation, Mission and Session owns the event log, the RTDB live tree, the sembast file and the host (Q24 restated for D's terms) | The **session** is the unit of live play (what the code and chapters 01 to 08 call an operation today); mission, operation and campaign are containers whose state carries forward through head snapshots and which are archived separately | Spec-wide rename plan; 04 §Interfaces, 06 §RTDB model, 05, 12 §Archives and `missions`; if kept, the code identifiers `operation` stay until one mechanical `refactor/` PR |
| R-X0b | Firestore layout and archives per level (campaign, operation, mission, session) and which level carries settings, pack pins, join links and listings | Pack pinned per operation, settings per operation with per-session override, membership and join links per operation | 12 §Operations, §Archives, §Library; 02 §Operations pin packs; 11 §Invite links |
| Q5 | Requests between sittings; auto-confirm purchases | Queue under the operation until the Handler is online; no auto-confirm | 04 §Offline and sync semantics; F2 amendment only if auto-confirm |
| Q7 | Where messages between sessions live | The phone box of the mission; cleared when the mission ends (P17, now spanning 1 to 3 sessions) | none beyond R-X0 pruning |
| Q9 | Published mission content and id | Debrief forms plus the public text log of the mission's sessions; id generated when the mission starts | 11 §Library; 12 `missions/{missionId}` |
| N1-R1 | How lines are produced (decision 15) | Hybrid | as in N1 |
| N1-R2 | Name rule | Explicit reveal + fallback (`RevealName` / `NameRevealed` / `KnownAs`) | as in N1 |
| N1-R3 | Per-batch `textlog` relay | Keep (existing ruling) | none |
| N1-R4 | Fix per-audience narration before D's wording | Now | row 7 follow-up |
| N1-R5 | Reveals through the review gate | Not gated | none |
| R6 | D4 needs re-narration of the current session's stored text | Regenerate on a reveal or at session end; archived sessions untouched | row 7 follow-up; 04 §The operation loop; 05 text-log paragraph |
| R7 | Death at 0 Health: through the review gate? | Yes: part of the confirmed damage batch, so the Handler can edit the damage before death; Handler `KillCharacter` is not gated | 01 §Commands and events; 04 §The operation loop (F2) |
| R8 | Flashback against F2 ("rolled faces are never altered") | Additive logged event beside the roll; faces untouched | 01, 03 |
| R9 | Which of D's rulings unblock builds | Unblocked now (data and small engine changes): G1, G3, G13, P2, M1, G9. Waiting on D's follow-ups: M2 and M3 roll details, G4, G5, G7, G10, G19, FB1. Waiting on R-X0: everything touching mission or session records, Q33 rules | R sequences the rows |

## Feature plan items

### F1. Mission library seed cases

**Ruled (D, 2026-10-22):** the playtest players have agreed to appear. **The cases themselves are still to be listed (FD-F6).**

**Decides:** D. **Source:** meeting packet feature plan, item 7. **Today:** no library code. Existing closed cases from the lore and playtests, and the playtest players' consent. **Assumption:** none seeded until D lists them (no source; coordinator default). **Changes:** library entries through moderation (12 §Library); no code.

### F2. Sign-in code symbology

**Ruled (D, 2026-10-22): No.** The sign-in code does not need to be PDF417; any scannable code is fine. **Apply:** 11 §Badges and sign-in table: sign-in code symbology "any scannable code (QR allowed)"; the public badge stays PDF417.

**Decides:** D. **Source:** meeting packet feature plan, item 11. **Today:** no sign-in code built. Whether the short-lived sign-in code is also PDF417 like the public badge. **Assumption:** none yet; the sign-in function (P14) mints a value, and the symbology is a rendering choice in the companion and desktop UI. **Changes:** 11 §Sign-in code; the badge package proposal to R (11 §New dependencies) covers both symbologies.
