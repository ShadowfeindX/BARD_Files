# Diagnostic pack (generated example, not D's content)

An example and diagnostic scenario so the demo build has something to run before D writes the real one. R approved it as an exception to the no-invented-content rule (CLAUDE.md section 9, decision 5 of the demo brief). **It is never part of the final demo.** Every name and line says `PLACEHOLDER`.

## What it is

A pack is generated, not committed. `bash tool/build_diagnostic_pack.sh` builds the core pack, then copies it to `packages/content_core/assets/generated/diagnostic-demo/` (git-ignored) with the files in `overlay/` laid over it:

| Overlay file | Effect |
|---|---|
| `overlay/manifest.json` | Replaces the core manifest: id `diagnostic-demo`, publisher `diagnostic-generated`, tier `campaign`, verification `pending`. |
| `overlay/npcs/*.json` | Adds three NPCs (clerk, guard, informant). Their `attributes` are `null` (pending D, a warning). Each takes the existing threat class row for its stats: clerk and informant `human:F`, guard `human:E`; no other number is set. |
| `overlay/strings/en.json` | Merged into the core strings. All keys start with `demo.`: scene title, two places, four beats, phone messages, one whisper, two spoken lines. |

The build refuses to change any existing core file (a rule, a stat, a value) and refuses a repeated string key, so the overlay cannot alter a rule. `bash tool/build_diagnostic_pack.sh --check` fails when the generated pack is stale; `tool/check_all.sh` and CI run both. The engine test `packages/engine/test/diagnostic_pack_test.dart` loads the pack, checks every added name and line is marked PLACEHOLDER, and checks that every skill, difficulty, condition and sanity row the beats use exists in the core pack.

The pack format has no place or check kind yet (location data shape is open), so places and beats are display text in `strings/`, and the checks below are called by the Handler with existing commands.

## The scripted scene

Two player aliases and a Handler. Placeholder checks use only skills, difficulties, conditions and sanity rows already in the core pack. The pack has no outcome-to-consequence mapping, so the consequences below are suggestions the Handler applies by hand, not rules:

| Beat | Place | Check | Rules shown |
|---|---|---|---|
| 1. Talk to the clerk | Records Annex | Persuasion, Cat-D | check, breakdown on both panels |
| 2. Search the cabinets | Records Annex | Research, Cat-C | check; suggested partial success: Handler applies Stunned (condition) |
| 3. Slip past the guard | Annex to corridor | Stealth, Cat-D | suggested failure: Handler enters a small damage amount and applies Bleeding |
| 4. The corridor door | Service Corridor | Insight, Cat-C | sanity loss from Minor Supernatural Entity (2 to 3), through consequence review |

Also scripted: two phone messages from the informant (sent as that NPC), and one stat-gated whisper (the Handler picks the gate at play; the alert shows outside the phone and a log line is written, per DEC-15 and DEC-17).

**Keep every character above 0.** The outcomes at 0 Health or 0 Sanity have no ruling yet (FD-D1 open, FD-D3 changed). The test characters must start with Health of at least 3 and Sanity of at least 4 (Health is END x LCK, Sanity is WIS x LCK, so for example WIS 2 and LCK 2). The Handler enters the sanity loss within 2 to 3 and keeps any damage to 1 or 2; the pack picks neither (amount selection inside a range is open, G5).

## Removing it

Delete `packages/content_core/diagnostic/`, `tool/lib/diagnostic_pack.dart`, `tool/bin/build_diagnostic_pack.dart`, `tool/build_diagnostic_pack.sh`, `tool/test/diagnostic_pack_test.dart`, `packages/engine/test/diagnostic_pack_test.dart`, the generated `packages/content_core/assets/generated/diagnostic-demo/` (git-ignored), the two `build_diagnostic_pack.sh` invocations and their comment in `tool/check_all.sh`, the two steps in `.github/workflows/ci.yml`, the section "The diagnostic pack (example only)" in `docs/developer-guide/packs.md`, and the CHANGELOG entry. Nothing else refers to it. Nothing in the apps loads it yet; the composition row adds the asset line when it needs it. D's real demo pack replaces the example by its own folder; it does not edit this one.
