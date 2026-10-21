# Example content pack: a guided tour for D

This folder is a **small sample** of what a B.A.R.D. content pack looks like. It is made so you and R can look at the shape of it on Thursday and say "yes, that works" or "change this". It is not the finished core pack, and nothing in it is a new rule.

**What a pack is.** A pack is a folder of plain text files (JSON) that hold all the game's numbers and names: the difficulty table, the weapon damage table, the skill list, and so on. The app has no numbers of its own. If you change a number here, the game changes. If you want a new kind of thing the game has never had, that is an app change instead, and R handles it.

**How to read the files.** Each file holds one or more lists of entries, like tables in the book. Names and numbers are in quotes or plain. Most files carry a `source` note with the book page (for example "Rulebook p21"). You do not have to understand the punctuation to read them; look for the words.

**Notes in the files.** Keys such as `note`, `source`, `openItems`, `placeholder` and `gap` are explanations for you, not game data. The architecture spec says a pack with unknown keys is rejected, so these annotations would be stripped (or formally allowed) before a final pack ships.

**Placeholders.** Anywhere the book leaves something undecided, the file says so with the word `placeholder` and a gap number (G1, G5, and so on, the same numbers as your questions list in `rulebook-gaps.md`). Those spots are *not* choices. They are marked empty on purpose so you can fill them in. Where `explode` or another value is `null`, it is undecided. Where a file says `[D to write]`, the book has no text for that entry and the words are yours.

**Dice and formulas.** Dice are written as small blocks, for example `{"type":"dice","count":1,"sides":4,"explode":null}` means "one four-sided die"; `explode` says whether it rolls again on a max, and `null` means nobody has decided yet (gap G3). A formula such as Health is written as "multiply END by LCK." That is all the app ever does with them; there is no hidden programming. Two small additions are proposals for R to approve: a `var` block (a named number supplied at play time, used for a helper's skill bonus and for a new attribute score).

## What each file is

| File | What it holds | Where it comes from in the book |
|---|---|---|
| `manifest.json` | The pack's name, version, and who made it. | n/a |
| `attributes.json` | The nine attributes and the character creation limits (20 points, 1 to 3 each, cap 10). | p13 |
| `proficiency.json` | Untrained, Proficient (+1d4) and Expert (+1d6) as extra dice, and the starting allotment (3 Proficient, 1 Expert). | pp9-13 |
| `difficulty.json` | The difficulty table Cat-F 3 up to Cat-Ω 25, the main d6, partial success (within 2 of the DC), fumble (25% of the DC), Luck advantage and helping. | pp9-11 |
| `derived.json` | Health (END × LCK), Sanity (WIS × LCK), Evasion, Initiative Bonus, reactions per round, damage reduction. | pp13, 25, 27 |
| `skills.json` | The five skill categories and 13 sample skills. Each has a name, description, category, and attribute. One extra entry (`example_old_skill`, not real content) shows how a skill is retired; it would not be in a real pack. | p19 |
| `conditions.json` | Three sample conditions (names from the book, no numbers). | p15 |
| `disorders.json` | The six-row disorder table and the Disorder Check (WIL, DC 10). | p17 |
| `sanity_events.json` | The five sanity loss rows with their ranges. | p17 |
| `damage.json` | Weapon damage Cat-F to Cat-Ω (dice and MIN). | p21 |
| `vehicles.json` | Vehicle driving modifiers and durability. | p23 |
| `ranges.json` | Point Blank to Extreme, with penalties (Extreme is -5 per the print copy). | p26 |
| `occult.json` | Magic sanity costs by category and the ritual defaults. **The casting roll itself is shown as options only.** | pp29-30 |
| `advancement.json` | XP costs for the eight advancement purchases. | p31 |
| `threats.json` | A few human and supernatural enemy class rows. | pp35-36 |
| `items/` | Two sample items: a pistol and an armor vest. | p35 (pistol); armor has no values in the book |
| `techniques/` | One sample technique, a name and a description. | freeform |
| `npcs/` | One sample NPC, the Cult Footsoldier. | p36 |
| `strings/` | Display text, kept apart so wording can change without touching rules. | n/a |

A second, tiny pack sits next to this folder in `../example-operation/`. It is what one Handler's own session-only skill looks like: the same file shapes and checks, just owned by one game. This sample holds only its skills file.

## What is already decided

These are settled and shown as ruled:

- Proficiency is an extra die: +1d4 Proficient, +1d6 Expert.
- Health = END × LCK. Sanity = WIS × LCK.
- The top category is Cat-Ω. The Handler decides Omega values; printed ones are only defaults.
- The disorder table is a clean six rows. Extreme range is -5. The weapon table is for player weapons only; enemies and NPCs have their own numbers.
- A skill is a name, a description, one of five categories (organizational only), an attribute, and a proficiency.
- Sanity loss amounts are built in, and the Handler can change any value before players see it.
- Handlers can make their own skills and techniques for a single session, using the same file shapes. Spells have no shape: casting is one roll and the Handler describes the effect (this is itself still to be reviewed with D, see below).

## What is still open (placeholders in the files)

None of these were decided by whoever built the sample. Each is marked in the files.

| Gap | In plain words | File |
|---|---|---|
| G1 | Does "25% of the DC" for a fumble use the die alone or the total? | `difficulty.json` |
| G2 | What gives advantage, and what is disadvantage? | `difficulty.json` |
| G3 | Which dice roll again on a max: damage, proficiency, helper, focus? Left as `null` everywhere except the main d6 (printed). | `difficulty.json`, `proficiency.json`, `damage.json`, `occult.json`, `advancement.json` |
| G4 | Is there a limit on helpers? | `difficulty.json` |
| G5 | How is an exact sanity loss picked inside a range, what is the resist DC, which die rolls on the disorder table? | `sanity_events.json`, `disorders.json`, `occult.json` |
| G6 and C5 | Which attribute does casting use, when is sanity lost, and is casting one roll with no spell list? Options are listed. | `occult.json` |
| G8 | Armor values and whether damage reduction is rolled or fixed. | `derived.json`, `items/armor_vest.json` |
| G9 | What MIN means, and whether Strength adds to melee damage. | `damage.json` |
| G10 | Aim, and which attacks can be dodged. | `ranges.json`, `items/` |
| G11 | The numbers an enemy needs to attack and defend. | `threats.json`, `npcs/` |
| G13 | The old difficulty names (Tough DC 9 and others) have no home. | `difficulty.json`, `vehicles.json` |
| G14 | "Single use" purchases and Artifact Clearance. | `advancement.json` |
| G15 | Skill list: Mind Shielding (no category yet), and attributes for Insight, Eldritch Lore, Vehicle Modification. | `skills.json` |

G7 (dying and critical injuries) is open too but has no file yet, because the book has no values to put in one.

## Questions about the shape (not the rules)

These are about how the files are laid out, so they are good to settle on Thursday:

1. **Is it readable?** Could you open `skills.json` and add a skill without help?
2. **Descriptions.** Each skill has a description that is empty (`[D to write]`) because the finished book has none. Is that the right place to write them?
3. **Where the check rules live.** The main d6, partial success window and fumble fraction sit in `difficulty.json` in this sample. The design notes do not yet name a file for them.
4. **Placeholder marking.** The `placeholder` / `gap` / `openItems` notes are this sample's own way to flag open items. They are not in the design notes. Final packs would carry none.
5. **Typos.** Names are copied exactly as printed (Parinoia, "Ect."). Fix them in the pack?
6. **Sample size.** 13 of 45 skills; 4 human and 3 supernatural enemy rows of the 15 printed. The real pack fills each file out.

## What this sample is not

It is not tested by the app (there is no app code yet). The JSON was checked for correct syntax and every number was compared with the rulebook notes by a second reviewer (twice); its findings are fixed. The book itself, the PDF, is the source of truth; if a number here ever differs, the book wins and this file is wrong.
