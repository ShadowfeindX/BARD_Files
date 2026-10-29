# Follow-up for R, 2026-10-29

D's meeting ended early. His round-2 sheet is recorded in [10-pending-d-followup.md](10-pending-d-followup.md): 13 blocks answered, 29 open. The open ones are re-asked in plain language in [10-pending-d-followup-2-for-d.md](10-pending-d-followup-2-for-d.md). His homework and the discussion notes are in [10-pending-d-notes-for-d.md](10-pending-d-notes-for-d.md). This sheet is what needs R.

Each block: tick one box, add a note if you change it. Defaults are Victor's assumptions, not rulings. A blank block means Later.

## A. D's answers that need a structural call

**[R-A1] Settings level.** D: settings belong to the mission, start from base settings, and can be copied from another mission. R-X0b (2026-10-27): the campaign carries settings, pack pins, join links and listings.
D and R-X0b conflict on who owns settings (D: mission; R: campaign), so R must choose. Assumption (reconciliation): the campaign owns *base* settings, each new mission copies them (or another mission) and may override. The **pack version pin stays at the campaign** (characters carry across missions; a pin that differs per mission could break their numbers). Join links and listings stay at the campaign.
Spec edit: 11 §Terminology, 04 (session config resolution: mission override, else campaign base), 03 (config paths).
- [ ] Agree
- [ ] Change (for example pin per mission): ______
- [ ] Later

**[R-A2] Which level owns the event log (R-X0).** D's description (session log archived, snapshot carried into the next session, all kept until the mission ends) matches the unit that code calls "operation" today.
Assumption: the live unit is the **session**. Rename in one mechanical `refactor/` PR (code identifiers stay until then): engine `Operation` becomes `Session`; the new hierarchy levels (campaign, operation, mission) are metadata above it. No behaviour change.
- [ ] Agree (rename plan to follow as a separate row)
- [ ] Change: ______
- [ ] Later

**[R-A3] Rollback and retention.** D wants every session's archive and snapshot kept until the mission ends so a Handler can roll back.
Assumption: Firestore archive chunks per session kept for good (a change beyond D, who said archives are kept until the mission ends; kept so the log doubles as a story record); snapshots kept until mission end, then only the last is kept. Rollback = Handler starts a new session from an earlier snapshot; later sessions stay archived and are marked superseded, never deleted. Storage cost to be estimated once snapshot size is measured.
- [ ] Agree
- [ ] Change: ______
- [ ] Later

**[R-A4] Handler persona model.** D: a persona is campaign-scoped, not tied to the GM account, has stats set by the GM, is the only identity players see inside an operation, and can move between campaigns. Players see the GM account only when accepting a campaign invite.
Assumption: persona = a character-shaped entity owned by the campaign (same component set as an alias, GM-controlled), referenced by operation. Moving it to another campaign copies it (D said "moved"; this is a suggestion to D in FE-L3). Needs a profile-visibility rule: inside an operation the roster shows the persona, never the GM account.
Spec edit: 11 (agents, aliases and profiles), 07 (roster UI), 03 (visibility).
- [ ] Agree
- [ ] Change: ______
- [ ] Later

**[R-A5] Personal library.** D: everything a player writes or is mentioned in is available in a personal archive. This is new scope (a per-account view over archived documents, debriefs, summaries, handouts, notes, phone messages).
Assumption: a read-only index in Firestore per account pointing at archived items the player was an audience for; no new storage of the content itself. Treat as post-v1 unless you say otherwise; D confirms the document kinds in FE-L5.
- [ ] Agree (post-v1)
- [ ] Change (in v1): ______
- [ ] Later

**[R-A6] Players managed at campaign level.** Invites, removal and roster live at the campaign; the Handler picks which characters join which missions. This reverses the earlier assumption that invites are per operation, and your 2026-10-21 approval that `members` stays as a locked stub under the operation.
Assumption: join links and `members` move to the campaign path; per-mission participation is a list of alias ids.
Spec edit: 06 (RTDB `members` placement and rules), 11, firebase rules (gated row).
- [ ] Agree (rules change goes through the Opus gate)
- [ ] Change: ______
- [ ] Later

## B. Magic and sanity (pack and engine)

**[R-B1] Focus item versus artifact in the pack.** D clarified: a focus item grounds the agent and *reduces* the Sanity cost; an artifact is dangerous, has its own will, and is the thing the book calls a "focus item" (rule under Casting & Rituals: +1d6, +2 Sanity per category above D).
Assumption: rename pack keys so `artifact` holds the book's rule (as it is today under the old name) and `focusItem` is new and `null` until D rules (reduction amount, whether category depends on personal relevance; re-cut as FE-M5..M9).
- [ ] Agree
- [ ] Change: ______
- [ ] Later

**[R-B2] Catastrophic failure via a random table.** Your suggestion (roll a die, look up the outcome, like wild magic) fits using a focus item and an artifact together, and also the disorder tables.
Assumption: add one generic pack kind, `randomTable` (id, die, rows of text plus optional effect keys), and a logged `TableRolled` event beside `CheckResolved`. The tables' *content* is D's homework; the engine ships no table rows. Uses the seeded logged RNG.
- [ ] Agree (design as an Opus row)
- [ ] Change: ______
- [ ] Later

**[R-B3] Sanity bands.** D agreed FD-S1 (bands at 20, 40, 60, 80 and 100%). The reworked sanity tables themselves are D's homework; pack values stay `null` until then.

## C. Items still open from earlier sheets

**[R-C1] Q5 auto-confirm.** Q5 is requests between sittings (purchases, contact releases) and whether purchases auto-confirm; rolls are never gated (F2). Assumption: a settings boolean, default off (Handler confirms), living at whichever level R-A1 picks (F2 currently says per-operation).
- [ ] Agree
- [ ] Change: ______
- [ ] Later

**[R-C2] Q7 phone box clearing time.** Contact list = campaign, messages = operation (ruled). Your 2026-10-21 P17 ruling cleared the box when a mission ends; with messages now owned by the operation, should that become operation end? Assumption: yes, a reversal of P17 for you to confirm, since messages belong to the operation and missions can run in parallel.
- [ ] Agree
- [ ] Change: ______
- [ ] Later

**[R-C3] Narrator lines and name reveals (N1-R1..R5), R6, R9.** No change since the last post; they still need your rulings and are listed in 10-pending-d.md under "R-only items". R9 and the pack-dependent rows stay blocked on D's homework.
- [ ] Noted

**[R-C4] Exact book headings.** The D documents cite the book by section name. Only "Casting & Rituals", "Casting Flow" and "Occult Action Check" are confirmed; the rest are by topic. A PC session should extract the real headings from the rulebook copy so the D documents can be corrected before they go out.
- [ ] Agree (queue a PC extraction)
- [ ] Skip, D can cope

**Note:** claims about the current code and pack keys in this sheet are from the spec chapters and the kit, not re-verified against the code today.

**[R-C5] FD-X8 second half.** D answered what players may ask to join only in part; what may be published to the lore library is not yet answered and is re-asked in the notes for D.

## D. Order of work once answered

1. Apply R-A1..R-A6 and D's answered blocks to 10-pending-d.md, 09, 11, README glossary, CHANGELOG (mechanical).
2. Open rows: session rename (R-A2), campaign-level members and rules (R-A6, Opus gate), persona entity (R-A4), `randomTable` (R-B2).
3. D's homework (notes document, Part 1) blocks the pack values; nothing is invented meanwhile.
