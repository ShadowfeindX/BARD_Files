# B.A.R.D. Core Rulebook: coverage report

Prepared 2026-10-16 for R; **updated 2026-10-16 after R's clarification of how rules and content work** (section 1). Report only: no rulings are made here. D owns game content; R resolves against the physical copies.

## 1. Bottom line

**How the system works (R, 2026-10-16), applied throughout this update.**
- D publishes a base set of content shared by every pack. GMs may use it or ignore it, and may create their own skills, techniques, spells, abilities and conditions for any NPC, enemy or player. Custom content has the same features as default content but applies only to that game session. The contract is between GM and player.
- A **skill** is a name, a description, a category (one of five, organizational only) and a proficiency. Mechanically only the **attribute it applies to** and **whether the character is proficient** matter.
- **Spells have no schema.** A player either uses a named skill or "casts magic". The GM sets the DC and describes the effect; the result of the one casting roll decides what happens.
- **Sanity loss amounts are hard-coded** per category, and the GM can override any value before it is broadcast.
- What must be codified is **categories and their values** (reasonable defaults). Naming, describing and organizing stays freeform.

So "the book does not list X" is a gap only if the engine needs a **category, value or rule** to compute something. Catalogues (all skills, conditions, techniques, spells, items, bestiary stats) are D's base content or the GM's own, not engine gaps. The first version of this report listed 41 gaps; after reclassification (some merged, some dropped) **17 remained** (section 6; R has since resolved G12, G16 and G17). Section 6.3 shows what happened to the dropped ones.

**Findings (unchanged by the clarification).**
- The canonical rulebook (`BARD Core Rulebook.pdf`, Scribus export, 41 pages, 2025-10-19) was fully recovered. Text layer extracted for all pages; every table page was also checked against the rendered page.
- **Three of the five flagged "extraction" problems are not conflicts in the book.** Health = END x LCK and Sanity = WIS x LCK; the category above S is **Cat-Omega**; the disorder table is a clean 1-6 table. Only the proficiency bonus (C1) and the Occult attribute (C5) are real inconsistencies.
- **10 further internal inconsistencies** are in section 5.
- Compared with the older 1.3/1.3.1 book it dropped several rules and a lot of content (section 7). Whether each cut was intentional is a question for D.
- `BARD Character Sheet.html` (2025-10-20) and `B.A.R.D Agent Dossier P-01-B.pdf` (2025-11-17) are evidence, not canon. They give a **default attribute for 43 of the 45 skills**, the "damage dice explode, capped at MIN" rule, and the armor-DR formula. Under R's model the attribute per skill is a field of each base skill, so these are D's source for filling it in.

## 2. Sources and method

| Source | Role | Notes |
|---|---|---|
| `BARD Core Rulebook.pdf` | Canonical (R) | 41 pp, letter, Scribus 1.6.4 + iLovePDF. Pages 1 (cover), 32 (illustration), 38 (blank) carry no text. |
| `The B.A.R.D. Files - Core Rulebook1.3.1.pdf` | Reference, older | 36 pp, internally "Beta 1.1, 9/28/25". Flat +3/+5 proficiency. |
| `BARD Files V2.1.txt` | Reference, oldest | Older dice-pool system (Nd6). Has per-skill descriptions and linked attributes. |
| `BARD Character Sheet.html` | Evidence | 2025-10-20, matches the canonical numbers. |
| `B.A.R.D Agent Dossier P-01-B.pdf` | Evidence | 2025-11-17 form; skills grouped by attribute. |
| `docs/architecture/` (`ShadowfeindX/BARD_Files`, branch `docs/architecture`) | Engine needs | Chapters 01, 02, 09. |

Method: `pdftotext -layout` on all 41 pages, then rendered pages 5, 9, 13, 17, 19, 21, 22, 23, 30, 31, 35, 36 and read every table as an image. Where the text layer and the image differ, the image wins and the difference is noted. Nothing was edited; originals were read only. The `.bard` folder was not opened.

Limits: I read the PDF, not the physical book. If the print differs from the PDF, the print wins.

## 3. What is in the canonical rulebook

PDF pages. "Confidence" is how certain the recovered values are.

| § | Title | PDF pp | What it contains | Confidence |
|---|---|---|---|---|
| 1 | Introduction | 5-7 | History (Society of Intrigue, 1875 Boston, Tunguska 1908), Directorate briefing, motto *Custodes Arcana et Verum* | High. Lore only. |
| 2 | Core mechanics | 9-11 | 1d6 + attribute + proficiency vs DC; DC table F-Ω; modifiers; assistance; Luck advantage; exploding die; partial success; fumble; 3 worked examples | High (table viewed). Internal conflicts, see C1, C6-C8. |
| 3 | Character creation | 13 | 20 points, 1-3 per attribute, 9 attributes; 3 Proficient + 1 Expert; derived Health, Sanity, Evasion, Initiative Bonus | High (formula boxes viewed). |
| 4 | Vitality | 15-17 | Critical injury triggers, conditions vs afflictions, scars, Sanity check, Sanity loss table, disorder check and table | High. Rules are mostly narrative. |
| 5 | Skills | 19 | 45 skills in 5 categories; opposed checks; `*` skills usable on Occult Action Checks | High (page viewed). No attribute links. |
| 6 | Equipment, armor | 21-23 | Equipment philosophy, weapon damage table F-Ω, vehicle assembly, vehicle performance and durability tables | High. Armor has no table. |
| 7 | Combat | 25-27 | Round, initiative, Major/Minor/Reaction, Dodge, Parry, movement, range bands, Evasion, DR, damage, vehicle combat, crash tests | High. Several gaps, see section 6. |
| 8 | Magic | 29-30 | Occult Action Check, ritual time/participants/focus items, magic category sanity costs, casting flow | High. C5 and C9. |
| 9 | Advancement | 31 | XP cost table (8 rows) | High (table viewed). No XP awards. |
| 10 | Handler's guide | 33-37 | Mission flow, sanity safety, threat classes, human adversary table, supernatural table, 13 named supernatural entities | High. Cat-Ω row has a layout glitch, see C10. |
| App. A | Principles of Unreality | 39-41 | Anomalous locations, Fey Lands, Land of Lost Things, Weird Science, Unsanctioned Operators | High. Lore only. |

Rules content is in §2-§10. §1 and Appendix A are setting material with no engine impact.

## 4. The five flagged conflicts

### C1. Proficiency bonus: dice or flat. RESOLVED by R (2026-10-16)

**R's ruling:** "Proficiency Bonus is an additional dice roll" (+1d4 Proficient, +1d6 Expert). The flat +3/+5 in §3, §5 and §10 are stale and need rewriting in the book and pack.


| Where | Says |
|---|---|
| §2 table (p9), quick reference (p10), three worked examples (p10) | Proficient **+1d4**, Expert **+1d6** |
| §3 Step 2 (p13) | Proficient "add **+3**", Expert "add **+5**" |
| §5 Skill Usage (p19) | "add the relevant skill bonus (**+3 or +5**)" |
| §9 XP table (p31) | "New Proficient Skill (**+1d4**)", "Upgrade to Expert (**+1d6**)" |
| §10 human adversary table (p35) | Flat: "+3 (Combat Skill)", "+5 Firearms / +3 Tactics", "+4 all / +5 WIL", "+6 WIL" |
| Character Sheet (2025-10-20) | "+1d4", "+1d6"; roller offers +1d4 / +1d6 |
| Rulebook 1.3.1 (Beta 1.1) | Flat +3 / +5 everywhere |

The book itself is split: §2/§9 and the sheet use dice; §3/§5/§10 use flat numbers. The dice form looks like the newer intent (older 1.3.1 and V2.1 are flat) but §3, §5 and §10 were not updated. Consequences: NPC threat tables are written in flat bonuses; the exploding rule says the proficiency die does not explode (p11), which only makes sense for dice.

### C2. Health / Sanity operators. RESOLVED by rendering

Rendered p13 shows **Health = ENDURANCE (END) × LUCK (LCK)** and **Sanity = WISDOM (WIS) × LUCK (LCK)**. The "?" in the extracted text is the multiplication sign. Confirmed independently by 1.3.1 ("END 4 × LCK 3 = Health 12"), V2.1 ("4 × 3"), and the Character Sheet ("Max HP = END * LCK + Bonus", "Max SAN = WIS * LCK + Bonus"). The sheet adds a bonus modifier term the book only implies (the §9 "Formidable"/"Unshakeable" +3 purchases).

Evasion = DEX + LCK and Initiative Bonus = DEX + LCK (additive, p13). Note Evasion and Initiative Bonus are the same formula; the roll itself is 1d6+DEX+LCK (p25).

### C3. Category above S. RESOLVED by rendering

It is **Cat-Ω** (Greek capital omega, "Omega"). Every table that has it, as rendered:

| Table | Cat-Ω value |
|---|---|
| DC table (p9) | DC **25** |
| Weapon damage (p21) | Damage shown as **∞**, MIN **11+** |
| Vehicle performance (p23) | Driving modifier **???** |
| Vehicle durability (p23) | HP **∞** |
| Magic sanity cost (p30) | "Instant collapse (0 sanity)" |
| Human adversary (p35) | Health 50+, DR 10, "!They Could Literally Have Anything!" |
| Supernatural (p36) | Health 100+, DR 15+, damage "Cat-Ω+ (5d6+, min 15+)", Sanity 12+ |

So the key and name are settled. What is **not** settled is its *value* in several tables (unbounded damage, unknown driving modifier). 1.3.1 says "Handler's Choice" for damage and driving modifier, "Infinite HP" for vehicles.

### C4. Disorder table. RESOLVED by rendering, with content gaps

Rendered p17 is a clean table, rows 1-6 aligned:

| Roll | Disorder (as printed) | Effect |
|---|---|---|
| 1 | Parinoia | CHA checks -3 with non-team NPCs |
| 2 | Phobia | Checks -2 during Phobia trigger |
| 3 | Obsessive Behavior | -1 to all actions during compulsion |
| 4 | Flashbacks/Ect. | DC 8 WIL or lose turn when exposed to trigger |
| 5 | Night Terrors | DC 8 WIL to sleep; failure -1 to all actions until properly rested |
| 6 | Amnesia/Ect. | -1 to -3 to INT skills depending on severity and task |

Open content points (not extraction problems):
- The book never says what the table is rolled for. The sentence "A failure means the agent gains a Long-Term Disorder (roll 1d6)" exists in 1.3.1 but is **absent** from the canonical text. Implied: roll 1d6 on a failed Disorder Check.
- Rows 4 and 6 say "/Ect." (typo for "Etc."). 1.3.1 had "Flashbacks/Night Terrors" and "Amnesia/Dissociation", plus an "Intense Distrust" row that the canonical drops, so Night Terrors moved to its own row 5.
- "Phobia trigger" is undefined (1.3.1 named Claustrophobia/Agoraphobia).
- No duration, no repeat-disorder rule, no stacking rule. Only recovery: XP cost 10 "via treatment" (p31).
- Typo for D: "Parinoia".

### C5. Occult attribute. OPEN (real conflict)

| Where | Says |
|---|---|
| p29 "Occult Action Check" | `1D6 + (WIL/INT) + Proficiency` |
| p29 "Casting & Rituals" | `1d6 + relevant Attribute (WIS or INT) + Skill bonus + modifiers`, "a more advanced Occult Action Check" |
| p30 Casting Flow step 3 | `1d6 + relevant Attribute (WIS or INT) + Skill bonus + modifiers` |
| p29 prerequisite text | Needs "a rank in an appropriate **Willpower (WIL) Proficiency**" (Ritual Magic, Advanced Alchemy, Exorcism, Forbidden Rituals, Mind Shielding) |
| p16 (Sanity check) | Sanity check uses WIL |
| Rulebook 1.3.1 | "WIS or INT" in the intro, "**1d6 + WIL**" in the casting flow |
| Dossier P-01-B | Ritual Magic, Advanced Alchemy, Exorcism, Forbidden Rituals, Mind Shielding sit under **WIL**; Arcane Knowledge and Occult Lore under **INT**; Cult Tactics under **WIS** |

Three attribute pairs appear (WIL/INT, WIS/INT, WIL) in one chapter. Related: the Occult Action Check and "Casting Check" are described as the same check at different names, and "Skill bonus" vs "Proficiency" wording follows C1. "Mind Shielding" appears in the p29 prerequisite list but **is not in the §5 skill list** (it is on the dossier).

## 5. Further inconsistencies found

Not in the review's list. Listed for D/R; none resolved.

| # | Where | Issue |
|---|---|---|
| C6 | p11 | Exploding die: "applies to all rolls using any die, including Skill Checks, Attack Rolls, Initiative, Defense Rolls, and Damage Rolls" but then "applies only to the original core 1d6 roll". Damage dice are not a core 1d6. The Character Sheet says damage dice explode on max and are capped at MIN (so the sheet resolves it as: yes). Whether Luck-advantage extra dice and the +1d6 focus/assist dice explode is also unstated. |
| C7 | pp10, 27, 26 | **Named DC labels have no definition.** "Tough (DC 9)", "Moderate", "Advanced", "Extreme DC 21" appear in the crash test, stunts, passenger shooting and example 3, but the DC table is F 3, E 5, D 7, C 10, B 13, A 17, S 21, Ω 25. There is no DC 9 category. These labels are left from V2.1 (Basic 3, Moderate 6, Tough 9, Advanced 13, Extreme 17). Crash Test: DC 9 (Tough). Withdraw: DEX DC 9. Critical injury: "DC 9 or higher". |
| C8 | p27 | Shooting from a vehicle: "Close Range: **DC+2** (Moderate); Medium **DC+4** (Tough); Long **DC+7** (Advanced)". 1.3.1 has absolute DCs 6 / 9 / 13. The canonical form is a modifier to an existing DC, but the labels still read as absolute DCs. |
| C9 | p29-30 | Sanity cost of magic: Casting Flow step 5 says make a sanity check "against the DC the Handler just assigned". The 1.3.1 rule was "after **successfully** casting". Canonical does not say whether the sanity check happens on failure too, nor how a point value inside a range (e.g. "3-5 points") is chosen. |
| C10 | p36 | Cat-Ω supernatural row text layer reads "15+ 10Cat-Ω+": a stray "10" appears in the render too ("15+ \| 10Cat-Ω+"), probably from the human Ω row's DR 10. Treat Ω DR as 15+ and the stray digits as a layout glitch; confirm in print. | **Resolved by R:** "an error in the PDF that does not appear in the printed copy".
| C11 | pp21, 36 | Supernatural threat "Damage Output" uses category labels that do **not** match the weapon damage table: Cat-A is "2d8, min **6**" in the threat table vs "2d8, min **7**" in the weapon table; Cat-S is "**3d6**, min 8" and "**4d6**, min 10" in the threat table vs "**2d10**, min 9" in the weapon table. Cat-E/D/C/B values match. | **Resolved by R:** "The weapon table is for damage from player weapons. Enemies and NPCs have their own individual values". Not a mismatch.
| C12 | p25-26 | Action economy: the book lists Major, Minor and Reaction, and says an agent performs "a combination of actions", but never states the per-turn limit. 1.3.1 says one Major and one Minor. Dash costs "both a Major and Minor action", which implies this. |
| C13 | p27 vs p15 | Death: §7 says that at 0 Health an agent is "Incapacitated and receives a Critical Injury". The book has no rule for death at all. 1.3.1 had a "Critical Injury Pool" (further damage beyond 0, > END = Dead) and a 6-row Critical Injury table. Both are gone. |
| C14 | p26-27 | Evasion is a static DC (DEX+LCK) "when the agent isn't actively avoiding", and a defender may instead spend a Reaction to roll Dodge (1d6 + DEX) or Parry (1d6 + STR + Melee Skill), where "equal to or greater than the attacker's roll" negates. That is described, but ties are resolved only for Dodge (defender wins); Parry, opposed skill checks (p19) and initiative are silent or left to the Handler. |
| C15 | pp13, 27, 35 | DR: §7 says DR = **END + Modifier** (static, from armor); the Character Sheet agrees ("Base DR = END score + Modifier from Armor"). 1.3.1 and V2.1 use a **roll** (1d6 + END + armor DR). The adversary table's DR values (0-15) are static. |

Minor text typos that will show in pack strings (for D): "Proficent", "competentancy", "Atttributes", "Useage", "apposed", "determin", "ect.", "Parinoia", "penelty", "Permenantly", "Assassaination", "Murphys", "Handlers Discretion", "Cat-d" (p35, Cat-D).

Skill list quirks: **Alchemy** (Technical) and **Advanced Alchemy** (Arcane) are separate skills; **Explosive Disposal** and **Explosives** are separate; Example 2 (p10) uses "Expert **Demolitions**", which is not a listed skill (the Character Sheet lists "Demolitions" and "Mechanics", "Diplomacy", "Charm", "Occultism" as example hints, none of which are in the list).

## 6. Gaps the engine actually needs filled

Reclassified under R's model (section 1). "Gap" now means: the engine needs a category, value or rule to compute an outcome and the canonical book does not give one unambiguously. Owner: **D** for a game-rule value or content, **R** for engine modeling or a print check. Priority: **B** blocks authoring the core pack; **S** the engine can ship with a stated default.

**Resolved by R on 2026-10-16:** G12, G16 and G17 (see the struck-through rows). Open: G1-G11 and G13-G15. G17 was resolved afterwards (Extreme range -5).

### 6.1 Remaining gaps

| # | Gap | Pri | Owner | Evidence / source |
|---|---|---|---|---|
| G1 | **Fumble basis.** "A roll of 25% or less of the DC": raw d6 or the total? Rounding? DC modifiers change the threshold. With a total, a low DC (e.g. 3, 5) can never fumble. Partial success ("within 2 points of the DC") uses the total, which suggests the total here too. | B | D | V2.1 used the raw die |
| G2 | **Advantage and disadvantage.** Advantage = extra d6 equal to LCK, keep the best total, but "if the player's LCK grants advantage" never says what grants it. Disadvantage is used (Evasive Maneuver, p27) and never defined. | B | D | V2.1: advantage = extra LCK dice |
| G3 | **Which dice explode** (C6, p11): contradictory. Open: damage dice, Luck-advantage dice, assist dice, focus-item +1d6, proficiency die (book says no). | B | D | Character Sheet: damage dice explode |
| G4 | **Assistance.** Helpers add 1d6 + skill bonus after passing Cat-D (p10): no cap, no explosion rule; ritual helpers use a different rule (DC 10, +1, p29). | S | D | |
| G5 | **Sanity and disorder values.** Also: the disorder roll (a failed Disorder Check implies rolling 1d6 on the table, but that sentence is absent from the canonical text) and the Sanity-check fumble band (p16: full loss +1 extra point and immediate complications; needs a stored rule). Engine needs one stored value per event row; the book gives ranges ("2-3", "3-5", "8+", "1 (fumble only)", Cat-Omega "instant collapse"). Also: no default DC for the trauma Sanity Check (p16), half-loss rounding, and whether partial success on Anomalous Hazard Damage (p27) is half or full. | B | D | 1.3.1 rounds group-cast cost up |
| G6 | **Magic roll flow.** One roll kind ("cast magic"): check attribute (C5), whether the Sanity Check is rolled on every cast or only on success (C9, step 5 vs 1.3.1), who pays Sanity in group casting (p29 silent; 1.3.1: all pay half), and which category a focus item's "+2 Sanity per category above D" counts (item's or spell's). Whether arcane proficiency is a hard prerequisite (p29 says it is) or a GM call. | B | D / R | C5, C9; 1.3.1 |
| G7 | **Death and critical injury.** The book has no death rule and no outcome rules. 0 Health = Incapacitated + Critical Injury. The Critical Injury Check is "usually END vs DC 9 or higher" and DC 9 is not a category (C7). The outcome catalogue itself is content, not a gap. | B | D | 1.3.1: damage past 0 goes to a Critical Injury Pool, > END = Dead |
| G8 | **Armor and DR.** DR = END + armor modifier (static, p27; sheet agrees) but 1.3.1/V2.1 roll `1d6 + END + DR` (C15). Weapons have a category table; armor has none: no category-to-DR values, so no default armor value exists. | B | D | 1.3.1: light 1-2, medium 3-4, heavy 5+ |
| G9 | **Melee damage.** Does STR add to melee damage (V2.1 yes, canonical silent)? Does MIN mean a damage floor (sheet: "capped at MIN") or something else? | S | D | V2.1; Character Sheet |
| G10 | **Action economy.** The book allows "a combination of actions" with no per-turn limit (C12). "Aim" is required for Extreme range but never defined. Which attacks can be Dodged: heading says "ranged or melee", text says "ranged attack" (p26). Parry tie rule. | B | D | 1.3.1: one Major + one Minor; Aim = Minor, +1 |
| G11 | **Threat class templates.** Tables give Health, DR, damage and Sanity but **no Evasion, attack bonus or initiative**; human skills are text ("2 Skills +3", "UNIQUE"). NPCs need numbers to run an attack and a defense. | B | D | |
| G12 | ~~Cat-Omega values~~ **Resolved by R:** "The handler decides Omega values. Any values actually listed will be presented as a reasonable default where available." | | R | |
| G13 | **Named DC labels and off-category DCs** (C7, C8). "Tough DC 9", "Moderate", "Advanced", "Extreme 17" and DC 9 for Withdraw, Crash Test and Critical Injury have no category (D = 7, C = 10). Vehicle shooting is "DC+2/+4/+7" with absolute-DC labels. | B | D | V2.1 named scale |
| G14 | **Advancement items.** "Single use" purchases (Tough Hide, Formidable, Unshakeable): once per character or repeatable? "Request Artifact Clearance (Limited)": what does it change in the engine? Attribute cap 10 versus the 1-3 creation cap is clear. | S | D | |
| G15 | **Skill list reconciliation.** "Mind Shielding" is a prerequisite skill on p29 but not in the §5 list. Eldritch Lore, Vehicle Modification and Insight have no default attribute on the dossier. Alchemy / Advanced Alchemy and Explosives / Explosive Disposal are separate base skills. Each base skill needs an attribute and a category. | S | D | Dossier P-01-B (43 skills), V2.1 (45) |
| G16 | ~~Proficiency bonus~~ **Resolved by R:** "Proficiency Bonus is an additional dice roll" (C1). | | R | |
| G17 | ~~Print check~~ **Resolved by R:** Extreme range is **-5** in the print copy (reply "-5"). The stray "10" (C10) and the monster-vs-weapon damage tables (C11) were also resolved by R. | | R | |

### 6.2 Engine and spec alignment (for R)

These follow from R's model and touch the architecture spec, not the book.

- **Skills, conditions, techniques, items are data, not engine vocabulary.** The spec's `Skills` component is "pack-declared skill key to proficiency tier key" and says keys are validated against the active pack. Per-session GM-created skills must therefore live in an operation-scoped pack with the same schema (spec 02 already allows GM packs; the scope and lifetime need to match "applies only to this session").
- **Skill schema:** name, description, category (fixed set of five, no mechanical effect), attribute, plus the character's proficiency tier. The pack's `allowed uses` / the book's `*` Occult marker (Research, Occult Lore, Linguistics) is a GM call per the book ("at Handlers Discretion"), so it need not be a field.
- **No spell schema.** `OccultSystem` in the spec lists ritual time, participants and focus items as engine concerns. Under R's model it needs one roll kind ("cast magic") with a GM-set DC (a category) and a sanity cost by category. Ritual time, participants and focus are GM-described, unless D wants them as optional defaults.
- **Every value is GM-overridable before broadcast.** The engine needs a defined override point for each category value (sanity loss, damage, DC) in `decide`, recorded in the event.
- **Conditions and disorders** are GM-created or D-published content with the same shape; the book's examples (Bleeding, Stunned, Prone, Blinded, Broken Bones) and the 6-row disorder table are D's base content, not engine rules.

### 6.3 What was dropped from the first version, and why

| Old # | Item | Disposition |
|---|---|---|
| M1, M4, M5, M8, M9, M17, M18 | Fumble basis, advantage/disadvantage, sanity DC, rounding, ranges, hazard partial | Merged into G1, G2, G5. |
| M7, M38 | Assistance, single-use purchases | Merged into G4, G14. |
| M12, M13 | Death rule, critical injury | Merged into G7 (outcome catalogue dropped as content). |
| M22, M23 | STR on melee damage, MIN | Merged into G9. |
| M26 | Reaction eligibility | Merged into G10. |
| M29 | NPC defense/attack stats | Merged into G11. |
| M2 | Partial-success window (DC-2 to DC-1) | Engine default: total within 2 below DC. Folded into G1 as a confirm. |
| M3 | No critical success | Not needed; exploding die is the upside. |
| M6, M11 | Modifier sign, ties | The engine takes signed modifiers entered by the GM; ties go to the GM (spec). |
| M10 | Skill-to-attribute defaults | Now a per-skill field. Source is the dossier; open items in G15. |
| M14 | Condition catalogue | GM-authored by design. |
| M15 | Recovery rates | GM-set by design (healing and Sanity recovery amounts). |
| M16 | Disorder duration/stacking/trigger wording | Disorder rows are base content; GM may extend. |
| M19, M30, M39, M41 | Scars, carry limits, ranks, encounter checklist | GM or narrative content. |
| M20 (list part), M21 | Armor and weapon lists, ammo, rate of fire, grenades | Items are D/GM content. Armor *category values* stay as G8. |
| M24 (part) | Full Attack, Take Cover | Optional base actions, GM-authored. Aim stays in G10. |
| M25 | Extreme range -5 vs -4 | Canonical is newest; kept only as a print check (G17). |
| M27, M28 | Vehicle range bands, speeds, weapons, ramming | Vehicle combat detail is GM-adjudicated; Cat-Omega stays in G12. |
| M31, M32, M35 | Spell/technique lists, backlash, ritual components | No spell schema; GM-described. |
| M33, M34 | Group casting, focus items | Kept inside G6. |
| M36 | XP awards | GM discretion. |
| M37 | XP cost economy differs from 1.3.1 | Canonical table is the newest; D confirm only if 1.3.1 numbers were intended. |
| M40 | Bestiary stat blocks | Entities are GM/D content; class templates stay as G11. |

### 6.4 Not covered by the rulebook at all (platform items)

- **Terminology:** the book says "Handler" (GM), "mission" / "case file" (operation), "Agent". R's vocabulary uses "alias" and "operation". "Alias" does not appear in the book.
- In-game phone messaging, badges, aliases and per-campaign locking, accounts and tiers: no rulebook text.
- Forms and records (government-style): not in the canonical rulebook. They live in older 1.3.1 (Forms B-77, B-12, Dossier P-409720-A) and the separate `Administrative Forms.pdf` / `Administrative Procedures Manual.pdf`.
- The **B.A.R.D. File Repository** (p21: "check the B.A.R.D. File Repository for ... Specific Artifacts or B.A.R.D. equipment") is referenced as an external resource; no content in the book. This is the natural home of D's published base content.
- Safety tools: only a boundaries-session recommendation (pp17, 34); no mechanics.

## 7. Content dropped since 1.3.1 (Beta 1.1) and V2.1

Present in 1.3.1 (Sept 2025), absent from the canonical (Oct 2025). Listed so D can say whether each is intentional.

| Item | 1.3.1 | Canonical |
|---|---|---|
| Critical Injury table (6 rows) and death rule | yes | prose only |
| DR roll `1d6 + END + DR` and armor tiers | yes | static DR |
| Aim, Full Attack, Take Cover | yes | not defined |
| Complex skill check DC 11+ | yes | gone |
| Backlash table (6 rows), group casting, ritual requirements | yes | partly (ritual time/participants) |
| Magic sanity check after success, Forbidden casting rule (Cat-S/Ω full loss) | yes | gone |
| XP awards (1-2 per objective, etc.) | yes | gone |
| Advancement costs 4 / 14-attr / 3 × score | yes | new table (10 / 20 / score × 10 + others) |
| Flat proficiency +3/+5 | yes | mixed, see C1 |
| Step 3 "Record background details" | yes | replaced by derived attributes |
| Quick reference tables (older DC scale 5/7/9/11/13/15+) | yes | DC table F-Ω instead |
| Bureaucratic forms B-77 / B-12 | yes | gone |
| Artifact repository (Ark of the Covenant, Catalyst, Heart of Wotan, Tunguska Fragment, The Colt, Shroud of St. Lazarus, Philadelphia Punch Card) with rules text | yes | gone |
| Key personnel (Franke, Korrina, Finch, Von Holt), case files (Nightfall, Cinder), lore files | yes | gone |
| Named human adversary archetypes with weapons (e.g. Pistol Cat-D) | yes | class descriptions in table; archetype examples as lists |
| Named supernatural examples per class | stat-table examples | 13 named supernatural entities as a separate index |
| Designer's notes | yes | gone |

V2.1 (older still) used a **dice-pool** system (Nd6 where N = attribute) and has per-skill descriptions and applications for all 45 skills. Those descriptions are not in either later book.

## 8. Readiness by pack file

From the architecture spec `02-rules-packs.md`. Split into what the **engine** needs from the book (categories, values, formulas) and the **base content** D publishes. "Full" = values are in the canonical book and consistent.

| Pack file | Engine values | Status | Open |
|---|---|---|---|
| `attributes.json` | 9 attributes, creation limits (20 pts, 1-3), cap 10 | **Full** | |
| `proficiency.json` | Tiers; creation allotment 3 Proficient + 1 Expert | **Partial** | G16 (dice or flat) |
| `difficulty.json` | 8 categories F-Omega, DC 3/5/7/10/13/17/21/25 | **Full** | G13 (labels, DC 9) |
| `derived.json` | Health, Sanity, Evasion, Initiative Bonus; DR = END + modifier | **Full** | G8 (static or rolled DR) |
| `skills.json` | 5 categories; fields name, description, category, attribute, tier | **Partial** (content) | G15 (attributes, missing skills); 45 base skills are D's list |
| `conditions.json` | Condition shape: name, description, optional numeric effects | **Content only** | Base examples (Bleeding, Stunned, Prone, Blinded, Broken Bones) are D's; no engine gap |
| `disorders.json` | 6-row disorder table; Disorder Check WIL DC 10 | **Partial** | G5 (disorder roll not stated); typos ("Parinoia", "Ect.") |
| `sanity_events.json` | 5 event rows | **Partial** | G5 (single values, DC, rounding) |
| `damage.json` | 8 categories with dice and MIN | **Partial** | G3, G9, G12 |
| `vehicles.json` | Performance mod and HP tables | **Partial** | G12 (Omega), G13 |
| `ranges.json` | 5 bands (0, 0, -1, -3, -5), distances | **Full** | G10 (Aim), G17 |
| `occult.json` | 8 magic categories and Sanity cost ranges (ritual time, 1 h per DC point in the book, is a GM-described optional default) | **Partial** | G5, G6 |
| `advancement.json` | 8 XP rows | **Full** | G14 |
| `threats.json` | Human F-Omega and supernatural E-Omega rows | **Partial** | G11, G12, G17 |
| `items/` | Item shape; armor categories | **Content only** | G8 (armor values); items are D/GM content |
| `techniques/` | Not needed as schema | **Content only** | Freeform: GM-authored by design |
| `strings/` | | n/a | Typos in section 5 |

## 9. Decisions for D and R

Marked **D** (game-rule value or content) or **R** (engine modeling or checking against the print). Recommendations are suggestions only; nothing is applied. Items with a G number are described in 6.1.

**R, check the physical copy first (D only if print is also ambiguous)**
1. ~~G16 / C1 proficiency form~~ **Resolved by R:** dice (+1d4/+1d6); stale flat values in §3, §5, §10 to be rewritten.
2. G6 / C5 casting attribute. Rec: default WIL for "cast magic" (1.3.1 casting flow and dossier), or the attribute of the skill the player names.
3. ~~G17 print checks~~ **Resolved by R:** Extreme range -5 per the print; stray "10" and the monster-vs-weapon damage tables resolved earlier.

**D, game rules**
4. G1 fumble basis. Rec: the total, 25% of DC rounded down; accept that low DCs rarely fumble.
5. G2 advantage and disadvantage. Rec: GM toggles; advantage = LCK extra d6, keep best total; disadvantage mirrors it, keep worst.
6. G3 exploding dice. Rec: primary d6 and damage dice explode; proficiency, assist, focus and advantage dice do not. Note this departs from p11 ("only the original core 1d6") and spec 01; it follows the Character Sheet and p11's own list that names Damage Rolls.
7. G5 sanity values. Rec: store min/max, engine rolls in range, open-ended rows get a floor; trauma DC per row by category; half rounds up; hazard partial = half.
8. G7 death and critical injury. Rec: restore the 1.3.1 death rule (past 0 to a pool, over END = dead); ship the 1.3.1 six-row table as optional base content.
9. G13 named DC labels and DC 9. Rec: retire the labels, restate each use as a category (Cat-D 7 or Cat-C 10) so crash test, Withdraw and Critical Injury Check use real categories.
10. G8 armor. Rec: static DR = END + armor value (canonical + sheet); add armor categories with flat values mirroring the 1.3.1 tier sizes (light 1-2, medium 3-4, heavy 5+), used as static numbers, not rolled.
11. G9 melee damage and MIN. Rec: no STR on damage (canonical silent), MIN as a floor (sheet).
12. G10 action economy. Rec: one Major + one Minor per turn; Aim is a Minor for +1. Dodge scope is your call: the heading says "Ranged or Melee", the text says ranged only (suggest Dodge any attack, Parry melee only).
13. G11 threat templates. Rec: add a numeric attack bonus and Evasion per class (derive from the printed class skill bonus), keep "anything" for Omega as GM-entered.
14. ~~G12 Cat-Omega~~ **Resolved by R:** the Handler decides Omega values; any listed values are reasonable defaults.
15. G6 magic details. Rec: sanity check on every cast (step 5); group casters pay half rounded up; focus item counts the spell's category.
16. G4 assistance and G14 single-use purchases. Rec: §2 assist rule for skill checks and keep the ritual exception (DC 10, +1); single-use = once per character; Artifact Clearance a GM-adjudicated flag.
17. G15 skills: add Mind Shielding to the list, assign attributes for Eldritch Lore, Vehicle Modification, Insight. Rec: INT, INT, WIS (V2.1).
18. Section 7 drops (critical injury table, backlash, artifact repository, forms, personnel): intentional? Rec: if yes, move artifacts and forms to the File Repository.

**R, engine modeling (no print needed)**
19. Per-session custom skills live in an operation-scoped pack with the same schema; skill = name, description, category (five, no effect), attribute, proficiency. Rec: yes.
20. "Cast magic" is one roll kind with no spell schema; trim `OccultSystem` to match; ritual time, participants and focus stay GM-described. Rec: yes.
21. Every category value is overridable by the GM before broadcast, recorded in the event. Rec: yes.

## Appendix: canonical values as printed

All from the rendered pages. Use for pack authoring once the open items above are ruled.

**DC (p9)**: F 3, E 5, D 7, C 10, B 13, A 17, S 21, Ω 25. Prose examples exist only for E (5+), C (10+), B (13+), A (17+), S (21+).

**Weapon damage (p21)** (category, dice, min): F 1d6 N/A; E 1d8 1; D 1d10 2; C 1d12 3; B 2d6 5; A 2d8 7; S 2d10 9; Ω ∞ 11+.

**Derived (p13)**: Health = END × LCK; Sanity = WIS × LCK; Evasion = DEX + LCK; Initiative Bonus = DEX + LCK. DR = END + Modifier (p27). Reactions per round = base DEX (p25).

**Creation (p13)**: 20 attribute points, 1-3 each; 3 Proficient and 1 Expert skill.

**Failure bands (p11)**: partial = within 2 of DC; fumble = 25% or less of DC.

**Range (p26)**: Point Blank 5 ft 0; Close ≤50 ft 0; Medium 51-150 ft -1; Long 151-500 ft -3; Extreme >500 ft -5 (needs Aim and Expert Firearms; Long impossible with Cat-E/F).

**Movement (p26)**: Standard 50 ft (Minor); Dash 100 ft (Major + Minor); Stealth Move 25 ft (Minor, Stealth check); Withdraw 75 ft (DEX DC 9).

**Sanity loss (p17)**: Gore/Violence/Sudden Death 1; Minor Supernatural Entity 2-3; Forbidden Rituals/Major Occult Site 3-5; Direct Combat with Major Entity 5-8; Dimensional Breach/Eldritch Event 8+. Disorder check: WIL DC 10 when below 50% max Sanity, after a Sanity-check fumble, or by Handler.

**Magic sanity (p30)**: F 1 (fumble only); E 1-2; D 2-3; C 3-5; B 5-7; A 7-10; S 10-15; Ω instant collapse (0).

**Ritual (p29)**: 1 hour per base DC point; each participant DC 10 Occult check for +1 to the caster; focus item +1d6 and +2 Sanity cost per category above D.

**Vehicle performance (driving mod, p23)**: F 1, E 2, D 2, C 3, B 4, A 4, S 5, Ω ???. **Durability HP**: F 5 (1 pax), E 8 (1-2), D 12 (4-5), C 16 (5-8), B 20 (10+), A 25 (4-6 crew), S 30+, Ω ∞.

**Crash (p27)**: 1d6 + Driving/Piloting (DEX), DC 9; failure = passengers take Cat-C melee damage. **Stunt** DC 9 to 17. **Passenger shooting** DC+2 / +4 / +7 (Close / Medium / Long).

**Advancement XP (p31)**: New Proficient 10; Upgrade to Expert 20; Attribute +1 (max 10) = new score × 10; Heal long-term affliction/disorder 10; Request Artifact Clearance (Limited) 25; Tough Hide (+1 DR) 50; Formidable (+3 Health) 50; Unshakeable (+3 Sanity) 50.

**Human adversaries (p35)** (class: Health, DR, skills/gear): F 3, 0, none, improvised; E 5, 1, +3 combat skill, light melee; D 8, 2, 2 skills +3, Cat-D pistol, armor vest; C 12, 3, +5 Firearms / +3 Tactics, Cat-C rifle; B 15, 4, 2 Social +5, Cat-B weapon or Focus; A 18, 5, +4 all / +5 WIL, artifact; S 22, 6, +5 all / +6 WIL, unique; Ω 50+, 10, "anything".

**Supernatural (p36)** (class: Health, DR, damage, Sanity): E 8, 0, Cat-E 1d8 min 1, 2; D 14, 3, Cat-C 1d12 min 3, 3; C 20, 5, Cat-B 2d6 min 5, 4; B 26, 7, Cat-A 2d8 min 6, 5; A 35, 10, Cat-S 3d6 min 8, 7; S 50, 12, Cat-S 4d6 min 10, 9; Ω 100+, 15+, Cat-Ω+ 5d6+ min 15+, 12+. Sanity loss applies per exposure event, not per round.

**Named entities (p36-37)**: E: Whisper Leech, The Stitched. D: Wraith Hound, The Charred Man, Room 313. C: The Archivist, Lament Engine. B: The Clockwork Seraph, The Pale Shepherd. A: Black Sun Herald, The Last Dream of Mankind. S-Ω: Entity 000 ("The Caretaker"), The Ω Construct. Human examples: F Frightened Witness, Cult Sacrifice Survivor; E Cult Footsoldier, Gang Enforcer; D Private Security Contractor, Rogue B.A.R.D. Agent, Smuggler Captain; C Cult Demolition Expert, Ritual Assassin, Corporate Recovery Team Lead; B Occult Commander of Sol Keep, Enhanced Asset, Psychic Interrogator; A-S+ Apostle of Nothingness, The Glass Knight, The Prototype Vessel.

**Skills (p19), 45**: Physical: Hand-to-Hand Combat, Firearms, Stealth, Lockpicking, Athletics, Parkour, Driving/Piloting, Melee Weapons. Investigation: Research\*, Artifact Identification, Occult Lore\*, Forensics, Surveillance, Interrogation, Cryptography, Tracking, Hacking, Linguistics\*. Technical: Engineering, Gadgetry, Explosive Disposal, Alchemy, Tech Manipulation, Trapcraft, Vehicle Modification, Medical Treatment, Explosives. Social: Persuasion, Deception, Negotiation, Seduction, Intimidation, Leadership, Disguise, Streetwise, Performance, Insight, Tactical Awareness. Supernatural: Arcane Knowledge, Ritual Magic, Advanced Alchemy, Exorcism, Eldritch Lore, Forbidden Rituals, Cult Tactics. (\* usable on Occult Action Checks at Handler's discretion.)

**Dossier P-01-B default attribute grouping (evidence, not canon)**: STR Hand-to-Hand, Melee Weapons. DEX Driving/Piloting, Firearms, Lockpicking, Parkour, Stealth. END Athletics, Medical Treatment. PER Forensics, Surveillance, Tracking, Trapcraft, Explosive Disposal, Disguise. INT Alchemy, Arcane Knowledge, Artifact Identification, Cryptography, Engineering, Explosives, Gadgetry, Hacking, Linguistics, Occult Lore, Research, Tech Manipulation. CHA Deception, Interrogation, Intimidation, Negotiation, Persuasion, Performance, Seduction. WIS Cult Tactics, Leadership, Streetwise, Tactical Awareness. WIL Advanced Alchemy, Exorcism, Forbidden Rituals, Mind Shielding, Ritual Magic. Not on the dossier: Eldritch Lore, Vehicle Modification, Insight.
