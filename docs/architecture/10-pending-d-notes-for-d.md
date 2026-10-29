# Notes for D: before the next meeting

This document has two parts. **Part 1** is the list of things only you can decide or write, so the build can continue. **Part 2** is discussion notes for the ideas you raised at the end of the last meeting: automated online play, damage reduction, and currencies. Part 2 is a set of options to react to, not proposals we have decided on. Nothing here is a rule.

Where a rule comes from the book, the section is named. We could not look up the exact heading for every section from here, so some are given as a topic (for example "the section on helping another character"); tell us if one is hard to find.

---

## Part 1: What D handles before the next meeting

Each item says what we need and why it matters. They are roughly in the order we expect to need them.

### 1. Focus items and artifacts

Why: the sanity cost of casting depends on this, and we had the two ideas mixed up.

- Write down how a **focus item** (a personal item that grounds an agent) reduces sanity cost: which actions it applies to, and how much it reduces.
- Confirm how an **artifact** works. The book's section "Casting & Rituals" gives it +1d6 on the roll and +2 Sanity cost per category above D. Say if anything about that should change.
- Design what happens when a focus item and an artifact are used together and the roll fails. You said any failure is catastrophic and the mechanics need work. One idea from R: the player rolls a die and the result is looked up on a table of outcomes. That needs a table of outcomes written by you (the table might have six to twenty entries, from "something minor goes wrong" to "the artifact takes over").

### 2. Reworked sanity tables

Why: you said sanity loss for events and for disorders gets reworked. Until your new tables arrive the app shows the book's current ranges as suggestions only.

- The sanity loss table (the section on sanity loss in the book, with entries like "2-3 points").
- The disorder table (the book's section on disorders and the table numbered 1 to 6). Say whether the table stays at six entries.
- Which events call for a resist roll, and who decides.

### 3. Armor and damage reduction (marked Later)

Why: every character has damage reduction, and the app needs a number. See the notes on damage reduction in Part 2. Pick up when you are ready; we will not build it before you do.

### 4. Enemy numbers (marked Later)

Why: the Handler needs numbers to run a fight with a class-based enemy. You said human adversaries get their stats from weapons and gear like players, so this only concerns supernatural enemies: how hard they are to hit, how good their attacks are, how fast they act. The book's enemy tables give Health, damage reduction, damage and sanity cost, but not these.

### 5. Advancement purchases (marked Later)

Why: the book's advancement section lists "single use" purchases (Tough Hide, Formidable, Unshakeable) without saying once per character or once per purchase, and "Request Artifact Clearance (Limited)" has no explanation.

### 6. Currency (marked Later)

Why: the store, the bank and the wallet need names, prices, starting funds and income. See the currency notes in Part 2, because R raised the idea of more than one currency.

### 7. Flashback design

Why: you asked for flashback to replace advantage and disadvantage. We need the numbers and limits.

- How big is the bonus (dice or a flat number, and how big)?
- How often can a player use it (per session, per mission, costs something)?
- Can it rescue a fumble?
- What kinds of reasons are acceptable (the Handler's guideline text for the app's reminder)?

### 8. Weapon numbers

Why: you set the rule for the lowest damage (MIN). The numbers themselves are needed.

- The MIN value for each weapon category in the book's weapon table.
- Any weapons you want listed individually.

### 9. Character creation details

Why: we need exact limits to build the character creator.

- What SKALD stands for, and the attribute limits for the rest of a SKALD's attributes (you gave one at most 4 and two at most 3, with 15 points in total).
- The most skills an agent may take.
- What the debrief forms contain (see item 10).

### 10. Debriefs, the lore library and the personal library

Why: you said the post-mission debrief is done by the Handler compiling the mission summary and each character filling in a form, and that post-operation and post-campaign processes are not yet defined. You also said you will re-review how the lore library takes submissions and how it is organized.

- The fields of the mission debrief form (the Handler's form and the character's form).
- Whether operations and campaigns get a summary or debrief of their own, and what is in it.
- How the lore library should be organized and how submissions are reviewed. You and R are the moderators for now.
- What each player's personal library should contain (we sent a question on this).

### 11. Mission library seed cases

Why: the playtest players agreed. We need the list of existing closed cases from the lore and playtests that should start the library.

### 12. Handler reminders and tooltips

Why: you asked for pop-up reminders and tooltips for GM features and abstract rulings. We need your first list: which rules or moments should show a reminder (for example, "when a player asks for a flashback, check the reason against past events") and what each should say. Short sentences are best. They will be stored in a text file that you and R can edit without any programming.

### 13. Things already decided that you may want to re-read

These were settled at the last meeting. They are listed so you can flag anything that looks wrong:

- Casting uses Willpower unless a skill is named; the Handler sets the final difficulty.
- A character at 0 Health dies; at 0 Sanity the Handler takes over the character.
- Sanity checks against the sanity band: 0-20% of maximum Sanity is Cat-S, 21-40% Cat-A, 41-60% Cat-B, 61-80% Cat-C, 81-100% Cat-D.
- Rounding always favours the player.
- Human adversaries use weapons and gear like players.
- Campaign > Operation > Mission > Session, with operations in sequence, missions in parallel and sessions in sequence.

---

## Part 2: Discussion notes

These are for the next conversation. They are options, with the questions that would help you choose.

### A. Automated single-player and online multiplayer

The idea: play The B.A.R.D. Files without a live Handler, alone or with other players online.

**What the system can already do that helps.** Every game event is recorded, and dice results are stored so a game can be replayed exactly. The app already has a setting for confirming consequences (damage, sanity loss) automatically instead of waiting for the Handler. The rules and content are kept separate from the program, so a scenario could be a content file too.

**Four ways it could work.** They can be combined.

1. **Scripted scenario.** A written mission with branches: places, characters, clues, and what each check leads to. The app plays the Handler's part from the script. Predictable, no outside service, but someone has to write each scenario, and it ends when the script does.
2. **Scripted scenario with AI help.** The same, but an AI model improvises descriptions, non-player dialogue and small deviations inside limits you set. The Handler's "panic button" (an AI-generated adventure hook) is currently proposed to use only the game content, the Handler's notes, the characters in play and our base information, never players' personal information or messages, with a visible notice that the text is AI-generated. The same limits could apply here. This option has ongoing running costs and needs R to choose the AI service.
3. **Handler-less online co-op.** Several players online with no Handler, using a scenario (option 1 or 2). It needs rules for who decides what the Handler would normally decide, such as which difficulty a check has.
4. **Open matchmaking with strangers.** Players join random groups. This raises safety questions: R has ruled that accounts without a login (clearance 0) cannot use voice, video or messaging, age checks happen at account creation, and only messaging can be reported. Strangers would need a decision on moderation before this could exist.

**Questions for you.**
- What is the experience you picture: a short "case file" you play in an evening, a persistent solo campaign, or co-op with friends who cannot find a Handler?
- Who writes scenarios: you, other writers, Handlers who share them (through the moderated library)?
- Which Handler decisions need rules before a program can make them? For example: who sets the difficulty of a cast, whether a flashback reason is accepted, and what happens at 0 Sanity (you said the Handler takes control; a program would need guidelines).
- Does death at 0 Health work the same way in a solo game?
- Is it part of the first version, or a later add-on?

### B. Damage reduction for players and enemies

**What the book has now.** The Core Rulebook's damage reduction is a flat number: Endurance plus a modifier, and the character sheet agrees. The book says armor "stats are largely narrative", so armor has no numbers yet. The older books used rolled reduction (1d6 + Endurance + armor, rolled every time you were hit), with light armor at 1-2, medium at 3-4 and heavy at 5 and above. The book's enemy tables give each enemy class a damage reduction number.

**Options for players.**
1. **Flat reduction with armor values** (the idea from the earlier sheet): damage reduction = Endurance + the armor's flat value. Simple, fast at the table.
2. **Rolled reduction** (older books): roll each time, so armor is less predictable. Slower, more variance.
3. **Armor by category** with narrative effects only (the book's current approach), and the Handler judges.

**For enemies.** The enemy tables already list a number. Questions: do supernatural enemies ignore some kinds of armor? (The book has anomalous attacks that deal sanity damage; should armor not reduce those?) Do human enemies follow the player rule, since you said they get stats from weapons and gear?

**Interactions to decide.**
- You set a floor on weapon damage (MIN). We asked whether the floor applies before or after damage reduction (a question on the follow-up sheet).
- Rounding favours the player. For damage the player takes, that means rounding down.
- Does damage reduction apply to damage from conditions, falling, or fire?

### C. Currency

**What we have.** You marked currency "Later". The provisional plan was one currency defined in the content pack: its name, prices, starting funds and income.

**R's idea:** more than one currency, to handle mundane and supernatural transactions.

**Options.**
1. **One currency**, with the Handler describing supernatural deals in words.
2. **Two named currencies**, for example everyday money and a supernatural currency, each with its own balance on the character's sheet.
3. **Several currencies** defined in the pack, so a campaign could add its own (favours, obligations, a cult's currency).

**Questions for you.**
- What counts as a supernatural transaction? (Buying an artifact? Paying an occult contact? Paying with something that is not an item?)
- Can the currencies be exchanged, and at what rate, or are they separate?
- Who can earn each one: only the Handler awards a supernatural currency, or players can too?
- Is spending or earning the supernatural currency linked to sanity?
- Is the supernatural currency visible to all players, or only to the characters who know about it?
- Should the supernatural currency be able to go negative, like a debt?
- What are typical prices and starting funds, once the currencies are decided?

The app will keep a balance and a list of transactions for each currency, and every change will show in the player's list, as already planned.
