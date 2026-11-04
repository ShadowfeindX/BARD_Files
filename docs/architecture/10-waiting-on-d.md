# 10. Waiting on D (and on R)

Status: everything R and D settled in the meetings of 2026-10-22, 2026-10-29 and 2026-11-03 is stated as design in chapters 01 to 08, 11 and 12 and the developer guide. This chapter keeps only what is **still open**. Nothing below is a ruling. A **default** is the coordinator's suggestion, marked as an assumption: it is not built, the pack keeps `null`, and the feature stays off until the ruling (CLAUDE.md §9). Rulings on game content are D's; R approves every implementation.

How it works:

- The D-facing sheets live in the project library (`meeting/D-followup-2.md`, questions; `meeting/D-notes-before-next-meeting.md`, homework and discussion notes), not in this repo. This chapter lists their question ids and a one-line subject; the sheets carry the book citations and the fill-in format.
- To apply a ruling: change the chapter that holds the design (named in the last column), the pack file if any (`packages/content_core/assets/example-core/` is the authoring source; `bash tool/build_pack.sh` regenerates the shipped copy), `CHANGELOG.md`, and delete the row here. The decision record (id, date, wording) is [decision-record.md](decision-record.md).
- If D picks something no default covers, the item is re-planned before any code, and the plan goes to R.

## 1. Unanswered questions for D

Asked on `D-followup-2.md` (round 3) unless noted. A blank answer counts as Later. "Changes" names the chapter, row or pack file that moves when D answers.

### Magic

| Id | Subject | Default (assumption) | Changes |
|---|---|---|---|
| FD-M1 | Who pays sanity at a ritual: the Handler marks who is present and who takes part; amount per payer | Each payer loses the full amount for the effect (not halved), Handler can change it | 01 Magic: casting, sanity cost, focus items and artifacts; `occult.json` `sanityPayers`; review tray |
| FD-M3 | Should the app help the Handler build a cast DC | A labelled factor list (time, helpers, circumstances, artifact) the Handler adds up and can overwrite | 07 Planned screens; occult row |
| FD-M4 | Casting without training: any numeric guideline | None; the Handler switches on "may cast anyway" per cast | 01 `missingOccultTraining` |
| FE-M5 | Focus item: which actions it reduces and by how much | None (no suggestion) | `occult.json` `focusItem` (stays `null`); 01 |
| FE-M6 | Who decides what counts as a focus item; how many | Handler approves; one at a time | `focusItem`; 07 |
| FE-M7 | Artifact keeps the book's rule (+1d6, +2 Sanity per category above D) | Keep as written; the Handler sets the category | `occult.json` `artifact` |
| FE-M8 | Does using an artifact need a resist roll (attribute, difficulty) | None (no suggestion) | 01; `occult.json` |
| FE-M9 | Focus item plus artifact, any failure catastrophic: outcome from a random table | Use a table (R-B2 design is agreed; rows are D's) | `tables/` content |

### Sanity, death, helping, combat

| Id | Subject | Default (assumption) | Changes |
|---|---|---|---|
| FD-S2 | One Willpower roll per sanity event against the band DC, replacing the book's DC 10 check; failure rolls 1d6 | One roll when the Handler calls for it after a loss | 01 item 10; `sanity_events.json`, `disorders.json` |
| FD-D1 | Incapacitated state and critical-injury check gone, or do parts of the book's "Incapacitation & Critical Injury" stay | Both gone; 0 Health is death | 01 `VitalsSystem` |
| FD-D2 | The Handler's one-click effects | Damage, sanity loss, add or remove a condition, temporary stat bonus or penalty, custom text | 07; effects list |
| FD-D3 | What gives control back after 0 Sanity | Only the Handler, after the character recovers Sanity | 01 `ControlTransferred` |
| FD-D4 | Who sees the death screen | The player who lost the character and the Handler; others see a log line | 07 |
| FD-D5 | Can the Handler undo a death | Yes, as a logged Handler action; players cannot | 01 `CharacterDied` |
| FD-A1 | Must a helper pass the Cat-D gate check first; may an untrained character help | Yes to the gate (as in the book); untrained may help | 01 item 9; `difficulty.json` `assistance` |
| FD-A2 | Which score a helper adds | The helper's own score in the roll's attribute; helpers allowed = roller's score + 1 | 01 item 9; `var` `helperAttribute` |
| FD-C1 | Aim, Dodge and Parry | Aim is a Minor action, +1 on a shot, needed beyond 500 ft; Dodge against any attack, Parry only melee | `combat.json`; `CombatSystem` |
| FD-C2 | When the reaction refreshes | Once per round, at the start of the character's turn | `combat.json`; `CombatSystem` |
| FD-G9 | Does Strength add to melee damage dice; is MIN applied before damage reduction; MIN per weapon category | Strength only as the floor; MIN before DR | `damage.json` `meleeFloor`, `min` values (homework 8) |

### Character creation and flashback

| Id | Subject | Default (assumption) | Changes |
|---|---|---|---|
| FD-G1 | Agent attribute caps beyond 5 and 4, and the lowest score | Others at most 3; lowest 1 | `attributes.json` creation profile `agent` |
| FD-G2 | How many skills an agent may take | Four slots, each Proficient or Expert, at least one Expert | `proficiency.json` creation profile |
| FD-G3 | SKALD: remaining attribute caps, lowest score, what SKALD stands for | None (no suggestion) | profile `skald`; 11 character kinds; app wording |
| FD-G4 | SKALD skills | At most one Expert and one Proficient, neither required | profile `skald` |
| FD-G5 | Can a SKALD become an agent (or the reverse) | No conversion in the first version | 11 |
| FD-G6 | Is an Occult Organization member its own kind or an agent alias | Agent limits, chosen as the kind at creation (reflected in 11) | 11 |
| FD-F1 | Flashback bonus size (dice or flat) | None (no suggestion; homework 7) | 01 Flashback; `difficulty.json` |
| FD-F2 | How often a flashback may be used | None (no suggestion; homework 7) | 01 Flashback |
| FD-F3 | Who approves the reason | The Handler accepts or refuses | 01 Flashback |
| FD-F4 | Can a flashback rescue a fumble | None (no suggestion; homework 7) | 01 Flashback |
| FD-F5 | What happens to Luck's extra dice and to disadvantage | Both go away; the Handler uses labelled modifiers | `difficulty.json` `luckAdvantage` removed |

### Levels, library and browsing

| Id | Subject | Default (assumption) | Changes |
|---|---|---|---|
| FE-L1 | Sessions sequential, missions parallel: a GM runs one episode at a time; two groups at once means two campaigns | Yes | 11 |
| FE-L2 | Settings per mission, copied from the campaign base; pack version stays campaign-wide | Yes (R agreed R-A1) | 04 settings resolution |
| FE-L3 | Handler personas: attributes, skills, gear; moving to another campaign copies it | Copy, original stays | 06 personas (R-A4 agreed the model; "moved" vs copy is D's) |
| FE-L4 | What is kept when a mission ends | R ruled R-A3 (only the latest snapshot is kept); D is asked to confirm, since logs of all episodes are then also removed | 06, 12 retention |
| FE-L5 | Personal library: which document kinds | Only what the player was meant to see; Handler-only documents do not appear | 07 personal library; 12 |
| FE-L6 | Players managed at campaign level | Yes (R agreed R-A6) | 06, 11 |
| FD-Q1 | Players without an account: exactly the free entries a free account sees, including free missions | Yes | 11 clearance tiers |
| FD-X8 (second half) | What may be published to the lore library; operations and campaigns as public listings | None; D will re-review the lore library and the post-operation and post-campaign debriefs | 11 library; 12 |

## 2. D's homework (nothing is invented meanwhile)

From `D-notes-before-next-meeting.md`, Part 1. The pack value stays `null` until D writes it.

1. Focus items and artifacts: the focus-item reduction, confirm the artifact rule, the table of outcomes for both together (six to twenty rows). Pack: `focusItem`, `artifact`, `tables/`.
2. Reworked sanity tables: sanity loss, the disorder table (six entries or more), which events call for a resist roll and who decides. Pack: `sanity_events.json`, `disorders.json` (FD-S3).
3. Armor and damage reduction (Later, see 3).
4. Enemy numbers for supernatural classes (Later, see 3).
5. Advancement purchase limits (Later, see 3).
6. Currency (Later, see 3).
7. Flashback design (FD-F1, F2, F4, acceptable reasons).
8. Weapon MIN per category in the weapons damage chart, and any weapons to list individually. Pack: `damage.json`.
9. Character creation details (FD-G1 to FD-G6) and the debrief form contents.
10. Debriefs, lore library and personal library: mission debrief fields (Handler and character forms), whether operations and campaigns get a summary or debrief, how the lore library is organized and its submissions reviewed (R and D moderate for now), the personal library contents.
11. Mission library seed cases (F1; the playtest players have agreed). Library entries through moderation; no code.
12. Handler reminders and tooltips: the first list of reminders and abstract rulings and their text (UI1, FD-T1). Idea for R: a Handler-hint component in `ui_kit` and hint text in the pack's `strings/`, editable without Dart.
13. Discussion notes (Part 2 of the notes): automated single-player and online multiplayer, damage reduction options, multiple currencies. Options only, no proposals.

## 3. Marked Later by D

| Id | Subject | Default (assumption) | Changes when ruled |
|---|---|---|---|
| G8 | Armor and damage reduction | Flat DR (END + armor modifier); light 1-2, medium 3-4, heavy 5+ | `derived.json` `damageReduction`, `items/*.json` `drModifier`; `VitalsSystem` suggestion |
| G11 | Enemy defense, attack and speed for supernatural classes | Defense and attack from the class's listed skill bonus | `threats.json`, NPC templates; parser `threats.dart`; 02 note on human adversaries |
| G14 | "Single use" purchases; Artifact Clearance | Once per character; Clearance is a Handler-tracked note | `advancement.json` `limit`; `CharacterSystem` purchase |
| Q6 | Currency: name, starting funds, income, prices; possibly several currencies (mundane and supernatural) | One generic `Funds` vocabulary with names in pack data | New `currency.json`, `price` on `items/*.json`, `Funds` component and transfer commands (wallet row); 11 Currency |
| Q12 | Fake websites (not in v1) | Handlers write them per operation; library sharing later | 11 Fake occult websites; `SiteRevealed` |
| FD-M2/M3c, FB1 | Focus item reduction; flashback details | See sections 1 and 2 | 01 |

## 4. Open for R

| Id | Decision | Options and default (assumption) | Changes |
|---|---|---|---|
| N1-R1 | How log lines are produced (decision 15) | (3) Hybrid: clients narrate their live log from their own feed; the host stores per-audience text narrated from that audience's knowledge | session row: `_narrate` once per audience; participant narrator; 04 Names in the log; 03 `textlog` unchanged |
| N1-R2 | Name rule | Explicit reveal plus fallback: `RevealName`, `NameRevealed`, `KnownAs` | engine row in `GmSystem`; narrator `nameFor(state, entity, viewer)`; `projectFor` case; codecs and `KnownAs` migration fixture; 01 |
| N1-R3 | Keep the per-batch `textlog` relay (P12) | Keep (R's earlier ruling stands unless changed) | none if kept; else 06 `textlog` branch |
| N1-R4 | Fix per-audience narration now, before D's wording | Now, with a placeholder fallback | session row |
| N1-R5 | Reveals through the review gate | Not gated (a reveal is not a consequence event) | none |
| R6 | D4 needs the current episode's stored text re-narrated | Regenerate on a reveal or at episode end; archives untouched | session row; 04; 05 text-log paragraph |
| R9 | Sequencing: which rulings unblock builds | Unblocked (data and small engine changes): G1, G3, G13, P2, M1, G9. Waiting on D: M2/M3 roll details, G4, G5, G7, G10, G19, FB1. | R sequences the rows |
| R-C5 / FD-X8 | Lore-library half: what may be published | Waits on D (section 1) | 11, 12 |
| Q5 | Requests between sittings (purchases, contact releases): where waiting requests are stored, and whether purchases may ever auto-confirm. R-C1 ruled the setting's levels only | Queue under the operation until the Handler's client is online; no auto-confirm (auto-confirm would extend F2, which covers consequence events only) | 04 Requests between sittings; 06 RTDB `requests`; F2 amendment and `EpisodeSettings` flag only if auto-confirm is chosen |
| Q9 detail | Mission id | Generated when the mission starts, independent of episode ids (assumption) | 11 Library; 12 `missions` |
| GM notes (decision 13) | Scope: notes per operation, per mission or both. Storage shape: one notes document beside the log, not events (the Opus-Gate recommendation, awaiting R) | Shape as recommended; scope open (assumption: per operation, with the Episode owning the log the fit is unclear) | 12 (a notes document), 06; engine unaffected |
| Money and records between missions | Bank, storefront and wallet between missions; "last 3 completed missions" on the profile; how the contact book persists inside a mission (the contact list itself is the campaign's, Q7) | None ruled; depends on Q6 currency (Later) and the mission records in 12 | 11 Messaging, Currency and Public profile; 12 |
| Wire names | Whether and when the v1 wire names (`startOperation`, `operationStarted`, `operationId`, envelope `op`) are renamed to Episode | Kept until an engine major bump, through the migrator, because stored logs are frozen per major (as built) | README naming note; codecs; 05 |
| Archive layout | Per-mission archive layout, genesis `archives` fields, `eventRange` unit across episodes, alias state between missions, R-A3 pruning step and where the last snapshot is kept, Handler persona document shape | Held in 12 (Held) | 12, 05 |
| R-A3 cost | Storage cost of snapshots, estimated once snapshot size is measured | n/a | 12 |
| R-A5 scope | Personal library implementation | Read-only Firestore index per account (R ruled it in v1; kinds are D's, FE-L5) | 07, 12 |

## 5. Workstream rows still to schedule

Ruled, not built; R sequences them (R9). Each is Proposed work, not a decision.

- Handler persona entity (R-A4): campaign-owned character-shaped entity, roster shows the persona.
- Campaign-level members and rules (R-A6): RTDB `members` move to the campaign; the rules change goes through the Opus gate.
- Operation-end phone box clear (R-C2): a function clears the box after the archive.
- Snapshot pruning (R-A3): after a mission is complete or submitted, remove all session data except the latest snapshot.
- Personal library index (R-A5), `randomTable` content wiring, and the rows listed in [01](01-engine.md#planned-code-changes).

The theme rulings of 2026-11-04 (T1 to T11) are stated in [07](07-apps.md#themes-and-player-appearance-settings) and recorded in [decision-record.md](decision-record.md); the theme items still open are in [09-open-decisions.md](09-open-decisions.md).
