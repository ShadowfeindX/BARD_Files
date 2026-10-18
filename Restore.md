# B.A.R.D. Project Restore File

Snapshot date: 2026-10-18. Written by Victor (the coordinator) before R moves the project to a new Claude account on 2026-10-19.

This file brings a fresh coordinator ("Victor") and its threads back to the exact state of the old project. It is self-contained. It replaces the old project chat, threads and memory, none of which carry over.

**Where copies live**
- Repo `ShadowfeindX/BARD_Files`, branch `restore/migration-2026-10-19`: this file at the root, and every library document under `restore/library/` with paths preserved.
- Old project library (may not survive the move): `/mnt/project-files/Restore/Restore.md` and `/mnt/project-files/Restore/library/`.

**No secrets are in this file.** Section 12 lists every credential, where it used to live, and what R must re-supply.

---

## Contents
1. Bootstrap for the new coordinator
2. People and how R wants us to work
3. Hard constraints and security rules
4. Product requirements
5. Game rules model and rulebook rulings
6. Architecture and versioning decisions
7. Backend stack and the test Firebase project
8. Tooling and environment setup
9. Thread-by-thread history
10. Library index
11. Open decisions awaiting R or D
12. Things R must redo on the new account
13. Pending work and next steps
14. Known errors and their fixes
15. Repository state

---

## 1. Bootstrap for the new coordinator

### 1.1 First steps, in order
1. Read this whole file. Then read `CLAUDE.md` on `main` (the project rules, merged via PR #1). CLAUDE.md wins over everything except R's later rulings recorded here.
2. Recreate project memory from section 1.2 (paste it in as MEMORY.md, or as project instructions).
3. Ask R to finish the account setup items in section 12 (GitHub, cloud environment, env var, network policy, Remote Control folders). Nothing below works until those exist.
4. Copy `restore/library/` back into the new project's shared library (`/mnt/project-files/`) with the same paths (`architecture/...`, `rulebook/...`), so threads can link to them again.
5. Check PR #2 (`docs/architecture`) is still open and at `fe30a99`. Check this restore PR's state.
6. Greet R once, briefly, as Victor. Say the restore is loaded and list what is waiting on R (section 11). Do not re-post old results.

### 1.2 Memory text to paste in (baseline)
The block below is the old project memory, updated to 2026-10-18. Every line of the old memory is in it.

```markdown
# B.A.R.D.
- Goal: build a full interactive platform for the tabletop RPG "The B.A.R.D. Files" (GM tools for hosting and NPCs, plus an immersive remote player experience).
- Owner: R, technical director. Address as "Director" or "R". Coordinator code name: Victor.
- D: creative director, co-author of the rulebook. Less technical. Has the final call on game content and content changes.
- Built in Flutter/Dart. Backend: Firebase first. Dart Cloud Functions are experimental (opt-in flag, Blaze plan, only onRequest/onCall deploy, not shown in console); R accepts using them where appropriate.
- Firebase preference (R, 2026-10-16): leverage Firebase features as much as possible (well-tested managed APIs, and the console lets D and content auditors fix issues without us). Dart server only where Firebase falls short; administration of any such API to be discussed with R.
- BACKEND STACK ADOPTED (R, 2026-10-16): client `firebase_dart` 1.6.2 on all desktop (Windows + Linux proven on R's PC). Live game data on Realtime Database (rules control writes). Server = HTTPS-only Dart Cloud Functions for badge tokens, roles, payments, moderation. Deps APPROVED by R 2026-10-16: firebase_admin_sdk (0.5.6: auth, messaging, storage, app_check, firestore, functions, security_rules; NO RTDB) and firebase_functions (0.8.0). Joins/archive moderation default to client writes under rules. Unverified lead: firebase_admin (appsup) may cover RTDB admin. Open: offline write surviving restart, Windows App Check, payments/app-store rules. Linux required in v1. Report: architecture/backend-split.md (+ review). Spec updated at 6ad4a29, deps approval at fe30a99 (open items B1-B6, Functions list P14).
- Test Firebase project: web-portfolio-2d5c2 (RTDB URL https://web-portfolio-2d5c2.firebaseio.com, no -default-rtdb; Firestore doc games/test). Credentials (web API key, test email/password) are NOT stored anywhere. They were only in R's messages in threads "Verify firebaseapis for desktop" and "Backend split without FlutterFire" (never copy them into memory or files). R re-supplies them in a thread when a probe needs them. PC auto-mode needs R to approve inline credentials in the thread itself.
- FlutterFire: Linux unsupported (flutterfire_desktop archived 2026-10-01); Windows not for production, cloud_firestore 7.0.0 failed to link on R's PC. firebaseapis is archived (2026-03-24), REST only.
- Google Developer Knowledge API: works everywhere. RC sessions on R's PC use a local MCP entry (C:\Users\R\.claude.json, project C:/GAMES/BARD). Cloud threads use env var DEVELOPERKNOWLEDGE_API_KEY in the project's default cloud environment, calling REST with curl: POST https://developerknowledge.googleapis.com/v1:answerQuery?key=$KEY, GET .../v1/documents:searchDocumentChunks?query=...&key=$KEY. Never print the key. Cloud network policy must allow Firebase hosts (RTDB needs *.firebaseio.com and *.firebasedatabase.app). Dart MCP on R's PC sometimes disconnects; restart the session.
- Main work folder on R's Windows computer (DESKTOP-1NG7AVU): C:\GAMES\BARD. ALL project work, scratch, temp and artifacts go there (worktrees under it are fine; set TEMP/TMP inside it). NEVER create files or folders outside C:\GAMES\BARD on R's PC without asking R first (this includes Claude memory folders, %TEMP%, /tmp, session scratchpads, read_project_file copies); say so explicitly in every brief to a PC session and every subagent/reviewer brief. Windows Flutter builds can hit MAX_PATH (FTK1011): ask R, don't move elsewhere. R-approved exception: Dart SDK in WSL2 (one-off, already deleted). Other folders are reference only. PC sessions can't read the library without copying outside; relay library content to them instead.
- Reference files may be COPIED into C:\GAMES\BARD/reference/ (source path noted in its README) and edited there. Never edit originals.
- Remote Control: start sessions by folder path (call list_devices first). Default: C:\GAMES\BARD. R's PC has Dart 3.13.x, Flutter 3.47.2, WSL2 Ubuntu.
- GitHub: ShadowfeindX/BARD_Files is the project remote. ShadowfeindX/bard is an older repo, not used. gh CLI is not installed on R's PC. PRs are opened from the coordinator session: add_repo (push), then an Agent worker uses the GitHub MCP. The tooling auto-appends a "Generated by Claude Code" footer: the worker must strip it and re-read. PRs are authored as ShadowfeindX, so R can't be requested as reviewer (assignee only).
- Claude Code's auto-mode on R's PC blocks agents from committing/pushing to main ("Git Destructive"). Agents work on branches only.
- Coordinator's cloud session cannot load the Dart MCP or write files directly. Shared library files (/mnt/project-files) are written by Agent workers or cloud thread sessions.
- Library docs: architecture/engine-pack-pinning.md, architecture/archive-log-example/ (rejected approach), architecture/firebase-desktop-deep-dive.md, architecture/backend-split.md + backend-split-review.md, rulebook/rulebook-coverage-report.md (G1-G17 + 21 decisions; thread "Rulebook coverage report"), rulebook/rulebook-gaps.md (plain-language gaps file for D; resolved gaps removed; 14 gaps left). Backup copies: repo branch restore/migration-2026-10-19, folder restore/library/. Full restore context: Restore.md.

## Game rules model (R, 2026-10-16)
- D publishes a base set of content shared by every pack; GMs may use or ignore it.
- GMs freely create skills, techniques, spells, abilities for any PC/NPC/enemy, with the same features as defaults, scoped to that game session. GM-player contract; UI reflects it.
- Skill = name, description, category (one of five; organizational only), attribute, proficiency. Only attribute and proficiency matter mechanically.
- Spells have no schema. "Cast magic" is one roll type; GM sets the DC and describes the effect; the roll result determines effects.
- Sanity loss amounts are hard-coded in rules; GM can override any value before broadcast.
- Codify categories and their values (reasonable defaults); naming, description and organization stay freeform.
- G12: the handler decides Omega values; any listed values are reasonable defaults where available.
- G16: Proficiency Bonus is an additional dice roll.
- G17: the stray "10" is a PDF error (not in print). Weapon table = damage from player weapons only; enemies and NPCs have individual values. Extreme range modifier is -5 (print copy).

## Reference material (inventoried 2026-10-15; full report was in thread "Inventory example operations and file formats", summarized in Restore.md section 9.1)
- Canonical rulebook: F:\My Drive\BARD\BARD Core Rulebook.pdf (Oct 20 2025, newest by date). R resolves issues against the published physical copies.
- Example operations (Cinder, Nightfall, No Place Like London) are narrative only. No files model the engine yet.
- Government file and code standards: F: drive (Administrative Procedures Manual PDF, Filing Code Standards, Administrative Forms PDF). Follow these. Early files don't always comply.
- No new strict templates now. Use the guideline style. Later, document templating will use Typst: documents defined as text/code, stored and distributed as compressed text, rebuilt on clients as styled PDFs.
- F:\My Drive\BARD\.bard (old Svelte/Firebase app) contains a .env and Firebase Admin SDK key for a TEST environment. R will handle it. Agents never open these.
- E:\My Drive\BARD: Obsidian notes (feature wishlist, cult lore) and images.

## Product requirements (R, 2026-10-15)
- Vocabulary: a player's account is their "agent". An agent has multiple "aliases". Gameplay sessions are "operations".
- Aliases belong to the account, each locked to ONE campaign at a time. Moving or exporting to another campaign needs GM approval. Otherwise only initial data (name, image, initial stats, initial skills) can be imported.
- Authority (confirmed): no server authority, no anti-cheat. Every client runs its own engine. Within an operation, the GM's client is canonical: players send requests, the GM engine resolves and broadcasts events. Network-hosted means the backend relays and persists events. Players and GMs may modify packs and clients freely.
- Backend role only: accounts, session state/data persistence, rules pack distribution, info dissemination, payments (badges, books, merch, account upgrade tiers).
- Offline: a signed-in account works offline, P2P and in isolation, from a local cache.
- Accounts: full or anonymous. Anonymous accounts can join any session and may have exactly ONE alias. They cannot GM, host or create content.
- Badges: optional scannable login (immersion only).
- App adjudicates rules where possible. The GM decides when a roll is needed and which skill, and can override any result.
- UI: theater of the mind. Panels for agent state, inventories, NPC details from player and GM views. Maps undecided.
- Immersion: in-game phone messaging, forwarded to the GM. Records use government-style formats.
- Public library: government-style archive. The public sees only items verified by R, D or moderators.
- Platforms: all Flutter targets incl. Linux in v1, landscape medium/large focus. Companion phone app in parallel.
- Web build (R, 2026-10-16): lightweight client for people who haven't installed the app; no full feature parity required. Web GMs can't host LAN (accepted). R may disallow GM hosting on web entirely (open item W1).
- Content: GMs create NPCs, items, skills, techniques. D (admin) publishes default content, cloud-hosted.

## Engine and pack versioning (decided 2026-10-15/16)
- Engine owns vocabulary (kinds of things and how they compute). Packs own values. App shell never affects outcomes.
- Engine updates apply to operations automatically by default. Pack updates are manual by default. GMs get a UI setting to make either or both automatic or manual.
- Seeded, logged RNG in the GM's engine.
- Event log stores resolved results, so history never changes.
- Rules majors are rare: a major gameplay change means republishing the physical manuals. Minor changes reach paid customers via notifications and marked online PDF versions.
- Cross-engine-major strategy (R, 2026-10-16): MIGRATOR ONLY. Each engine major knows only its own schema, zero compat code inside the engine. A separate migrator package transforms an operation's state and pack from major N to N+1. No frozen prior engine bundled, no old web build kept online.
- Compat decoding within a major (R, 2026-10-16): ALLOWED, additive-only, plus a deprecation marker. Spec agent proposed the marker as P11 at 62a0f34; awaiting R's approval.
- Archived logs after a major (R, 2026-10-16): ARCHIVE-ONLY, never converted. Old log frozen; plain-text rendering stored beside it, viewable in the in-game log or an archive viewer. New log starts with OperationMigrated genesis from prior state. GM must explicitly confirm unrecoverable loss. P12/P13 await R's approval (now on RTDB rules).

## Architecture (agreed direction)
- ECS-style pure-Dart domain, coarse actors for session/runtime, event-sourced core (command → events → state), monorepo packages (engine, protocol, session, migrator) shared by main app, companion app and functions.
- Architecture spec: Opus RC session (thread "Architecture spec"). PR #2 (docs/architecture, head fe30a99) open for R. Spec in docs/architecture/ (00-08 chapters, 09-open-decisions.md, verification.md) plus root CHANGELOG.md. R wants to review the architecture with Victor before the remaining open decisions.
- Still open (2026-10-18): rulebook gaps/decisions (R reviewing; D reviewing rulebook-gaps.md); P1-P14 approval; W1 web GM hosting; B1-B6 backend open items; spec concerns 3-7. Plus state mgmt (rec ChangeNotifier), routing (go_router), persistence (sembast + sembast_web), networking order (in-process, LAN, RTDB relay, P2P) in 09.

## PR description format (R, overrides any default template or attribution)
- Body is ONLY a changelog. No attribution, no session links or footers. A short "why" only for comprehensive changes.

## Rules doc
- CLAUDE.md at the repo root plus a .claude/settings.json PowerShell deny, merged via PR #1. Victor merges only with R's explicit permission. CLAUDE.md requires a second-agent review before work goes to R (applies to reports too).

## How R wants us to work
- Coordinator stays available for conversation. All work is delegated to the agent team.
- Team: 1 Opus (complex structural work), 2 Sonnet (organization, larger coding changes), 5 Haiku (small changes, verifying tests and docs). Set model per session.
- Blocked agents: Victor monitors all agents so R never has to. Decisions go to R in the project chat with full context and a recommendation, or a link to the blocked agent's thread. Merge agents' questions into Victor's own post.
- Terminal: Git Bash only. Never PowerShell, on any machine.
- Tools allowed for agents: Dart/Flutter MCP and skills, Dart context MCP, Google Developer Knowledge API, git and the GitHub repo. No other external tools unless R names them (R approved web research for the Firebase investigations, 2026-10-16).
- Any code-related info surfaced to R must first be verified by a sub-agent using those tools.
- Only R approves implementation/feature work. Only R issues actionable technical changes.
- With R: concise, technical language. With D: descriptive, exploratory explanations unless D asks otherwise. D's questions are answered, never turned into tasks.
- When R asks for "only" a list (e.g. gaps and decisions), deliver only that.
- Any unavailable tool or error that is not trivially fixed is escalated to R at once. Never force through.
- Proposed deviations go to R first. R's final decision stands.
- Output must stay maintainable so R and D can extend it without Claude.
```

### 1.3 Team model setup
R's instruction (2026-10-15): eight agents. Victor organizes them freely; R's recommendation is the default.

| Role | Count | Model | Use for |
|---|---|---|---|
| Opus | 1 | Opus (latest) | Architecture, data models, cross-cutting structural changes, hard bugs, rules-engine design. The architecture spec author. |
| Sonnet | 2 | Sonnet (latest) | Feature builds, refactors, multi-file changes, organizing docs and assets, inventories, reports. |
| Haiku | 5 | Haiku (latest) | Small fixes, tests, verifying claims, docs checks, second-agent reviews. |

- Set the model per session when starting it. No more than eight run at once.
- Every non-trivial change, and every report, gets a second-agent review before it reaches R (CLAUDE.md §3 and §4).
- Every brief to a PC session or reviewer must say: Git Bash only, never PowerShell; create nothing outside `C:\GAMES\BARD` (TEMP/TMP included); never open `F:\My Drive\BARD\.bard`; stop and report on any error or block.

### 1.4 How PRs are opened
- Remote: `ShadowfeindX/BARD_Files`. Agents work on `<type>/<short-name>` branches. Never commit or push to `main` (auto-mode on R's PC blocks it anyway).
- `gh` is not installed on R's PC. The PC agent pushes the branch; the coordinator side attaches the repo with `add_repo` (push access) and opens the PR through the GitHub MCP.
- PR body = changelog only, in this shape (R's own example):
  ```
  # Changelog
  - Added `CLAUDE.md` at the root. Sets the approved project rules, which every Claude session loads automatically.
  - Added `.claude/settings.json`. Denies the PowerShell tool.
  ```
  A short "why" only for comprehensive changes. No attribution, "requested by", session links or footers. The tooling auto-appends a "Generated by Claude Code" footer: strip it and re-read the body to confirm.
- PRs are authored as ShadowfeindX, so R cannot be requested as reviewer. Assign R instead.
- Only R merges, or Victor with R's explicit permission for that merge.

### 1.5 Remote Control default folder
- Device: R's Windows PC `DESKTOP-1NG7AVU`.
- Default folder: `C:\GAMES\BARD`. Always call `list_devices` first and start sessions by that exact path.
- Other approved folders (reference only, read-only): `D:\.code\_bard`, `D:\.code\bard`, `D:\.code\bard-web`, `F:\My Drive\BARD`, `E:\My Drive\BARD`.
- A Remote Control session on the PC only accepts approvals typed by R in its own thread. If auto mode blocks something because the instruction came via Victor, ask R to type the approval in that thread.

---

## 2. People and how R wants us to work

### 2.1 People
- **R**: technical director. Address as "Director" or "R". Familiar with Dart, Flutter, the packages and programming. Sole approver of implementation and feature work, sole source of actionable technical changes. GitHub login `ShadowfeindX`.
- **D**: creative director, co-author of the rulebook with R. Less technical. Final call on game content. May ask Victor about the project's state; answer descriptively and in plain language, never turn D's questions into tasks. R relays D's feature wishes to Victor himself.
- **Victor**: the coordinator code name. Stays available to R for conversation, delegates all work, monitors agents.

### 2.2 R's working rules, with dates
- 2026-10-15: "Your job is to remain available to me as much as possible during conversation. Any work that needs to be done should be delegated to your personal agent staff team." Questions about goals, designs or philosophy go to R.
- 2026-10-15: tool unavailable or error not simply fixed: bring it to R immediately, never force through. "You will be more rewarded for bringing such issues to my attention rather than deviating from my explicit instructions." Proposed deviations go to R first; "once I have made my final decision, that is what we will be going with."
- 2026-10-15: end goal is that R and D can expand the project on their own when Claude is not available.
- 2026-10-15: Git Bash for every terminal command. "Under no circumstances should PowerShell be used on this or any other machine."
- 2026-10-15: all work and artifacts in the main BARD folder on C: (`C:\GAMES\BARD`). Other folders are reference only.
- 2026-10-15: agents may use the Dart/Flutter MCP and skills, the Dart context MCP and (added later that day) the Google Developer Knowledge API, plus git/GitHub. No other external tools unless R names them.
- 2026-10-15: reference files may be copied into the working directory and edited there; never edit files outside the approved scope.
- 2026-10-15: "Ensure any pertinent code-related information that needs to be surfaced to me then is verified through these tools and skills by the sub-agents."
- 2026-10-15: R asked Victor to draft CLAUDE.md personally (not delegate), so Victor fully understands it. R edited the draft; R's version is canonical. Typo fix approved. PowerShell deny in `.claude/settings.json` approved.
- 2026-10-15: "If any agent gets blocked on work or tasks that require decisions, bring me the decision with the full context, or direct me to which agent is blocked... Otherwise, then I have to monitor all 8 of your agents myself."
- 2026-10-15 21:05: "Are you unable to check in with your agents yourself if they are blocked?" Settled that Victor monitors all agents himself and brings R only the decision or a link to the blocked thread.
- 2026-10-15: PR descriptions are changelog only (see 1.4).
- 2026-10-15: R alone approves finished implementation work. With R: concise, technical. With D: descriptive, exploratory unless D says otherwise.
- 2026-10-16 06:40 (architecture spec): "If there are any other blocking issues or concerns surfaced by the agent during the specification process, let me know."
- 2026-10-16: R approved web research for the Firebase investigations.
- 2026-10-16: "Why was a folder created outside the approved directories?" Rule tightened: nothing outside `C:\GAMES\BARD` without asking first, in every brief, temp included.
- 2026-10-16: "Let's clear up any other block threads as well." Victor resolves threads whose work is done.
- 2026-10-16: when R asks for "only" the gaps and decisions, deliver only that list.
- 2026-10-16: R wants to review the proposed architecture together with Victor before moving on to the remaining open decisions.

---

## 3. Hard constraints and security rules

1. Git Bash only. Never PowerShell, on any machine, including the PowerShell tool (denied in `.claude/settings.json`).
2. On R's PC, create nothing outside `C:\GAMES\BARD`: no `%TEMP%`, `/tmp`, scratchpad, Claude memory folders, short build paths, or library copies. Set TEMP/TMP to a folder inside `C:\GAMES\BARD` when needed and delete it afterwards. Worktrees under `C:\GAMES\BARD` are fine. Ask R first for any exception. The only exception ever granted was a one-off Dart SDK download into WSL2 (deleted afterwards).
3. Reference folders are read-only. Copy into `C:\GAMES\BARD\reference\` (note the source path in its README) and edit the copy.
4. Never open `F:\My Drive\BARD\.bard`. It holds a `.env` and a Firebase Admin SDK key JSON for a test environment. R said he will handle it himself.
5. Never write credentials, API keys, passwords or the test login into any file, commit, memory or PR. Pass them as per-command environment variables only, never print them, and mask output. R supplies them in a thread when a probe needs them.
6. Never commit or push to `main`. Never merge without R's explicit permission. Never force-push `main` or rewrite shared history. Never commit generated build output.
7. No new pub dependency without R's approval (CLAUDE.md §6).
8. Agents never invent rules, stats, lore, NPCs or mechanics. Gaps are reported, not filled. D owns content.
9. Agents only use the approved tools (section 2.2). Anything else needs R to name it.
10. A non-trivial change or report gets a second-agent review before it reaches R.
11. R's final decisions are not reopened. A new concern may be raised once.
12. Escalate any blocked tool or error that is not trivially fixed; no workarounds, retry loops or disabled checks.

---

## 4. Product requirements

All from R, 2026-10-15 unless dated otherwise.

- **Product:** a Flutter app to play *The B.A.R.D. Files* when players cannot be at the table together. GM side: host games, create and monitor NPCs. Player side: interact with the GM, the game and the world as immersively as a 2D screen allows. Tone: paranatural and supernatural events, fantasy and realism, Lovecraftian horror and psychological breakdown, plus ordinary detective work and gun combat.
- **Vocabulary:** an account is an "agent". An agent has several "aliases" (name, description, skills). Gameplay sessions are "operations". The rulebook says "Handler" for GM.
- **Play modes:** no restrictions. In person or over the network, any form factor. An operation is P2P (GM-hosted) or network-hosted. Once a GM hosts, players join from any device. R (21:59): both P2P GM-hosted and backend-hosted sessions are wanted; backend-hosted serves larger sessions and GMs or players without a reliable connection.
- **Authority:** no server authority and no anti-cheat. Every client runs its own engine. Within an operation the GM's client is canonical: players send requests, the GM engine resolves and broadcasts events. Network-hosted means the backend relays and persists events. Players and GMs may modify packs and clients freely (confirmed 2026-10-15).
- **Backend role only:** accounts, session state and persistence where needed, rules pack distribution, information dissemination, payments (physical badges, books, merch, account upgrade tiers).
- **Persistence:** data saves where the operation is hosted: on the GM's machine for P2P, in the cloud for cloud sessions.
- **Offline:** a signed-in account works offline, P2P and in isolation from its local cache (aliases, data). GMs likewise. Servers are needed only for account features, downloading packs and information, and purchases.
- **Accounts:** everyone needs an account, or uses an anonymous account. Anonymous accounts can join P2P or network sessions, may create exactly one alias, cannot register as GM, host or create content, and lack some features.
- **Aliases:** belong to the account and are visible across campaigns, but each is locked to one campaign at a time. Moving or exporting to another campaign needs explicit GM approval. Otherwise only initial data (name, profile image, initial stat spread, initial skills) can be imported, nothing gained in play, no items.
- **Badges:** physical badges with scannable codes that identify the person's account and log them in. Optional, for immersion only. Normal login always works.
- **Rules adjudication:** the app adjudicates all rules where possible, with the data codified in the data layer. The GM decides where a roll is needed and which skill. The GM can override any result.
- **UI:** theater of the mind. Panels for agent state, items per agent, NPC details from player and GM perspective. Maps undecided; leave room for them.
- **Immersion intent (R, 22:14):** players should "feel like they are part of a fake government organization centered around the containment of dangerous items and individuals and recording of sensitive psychological information." Files made by players and GMs use government-style formats (examples on the F: and E: drives).
- **Immersion:** in-game cell phone for messages to other players or NPCs, forwarded to the GM to act out. Mission logs and paperwork in government-style formats, filled in-app or imported as data files.
- **Content authoring:** GMs create their own NPCs, items, skills and techniques for their games. D gets admin-level control of the same tools to create default assets (weapons, items, vehicles, descriptions), uploaded for everyone, in-app or as data files. D's content is hosted in our cloud and downloaded into the app.
- **Sharing:** no method yet for GMs to share small homebrew (skills) with others. Planned: a public, government-style perusable archive of artifacts, NPCs and NPC types. GMs and players see their own uploaded session files; the public sees only items verified by R, D or the content moderation team.
- **Platforms:** all Flutter targets (mobile, desktop, web). Focus on landscape medium and large screens. A companion phone app is built in parallel, usable with the main app or alone at an in-person table (messages, creature lookups, past session info). Linux is required in v1 (2026-10-16).
- **Web build (2026-10-16):** a lightweight client for people who haven't installed the app yet, without full feature parity. Web GMs cannot host LAN (accepted). R may disallow GM hosting on web entirely (W1, open).
- **Versioning from the user side:** a session is pinned to its rules version, so players aren't forced onto new rules mid-campaign. App updates are not mandatory; players can finish a session on the app and rules version they started with, except on web, which auto-updates.
- **Backend platform:** Firebase first (Firestore and Hosting were the starting assumption; RTDB later adopted, see section 7). Google Cloud (e.g. App Engine or Cloud Run) only where needed for a Dart server.
- **Document templating (later):** Typst. Documents defined as text/code, stored and distributed as compressed text, rebuilt on clients as styled PDFs. No new strict templates now; use the style from the filing guidelines. D has the final call on content.

---

## 5. Game rules model and rulebook rulings

### 5.1 How the rules system works (R, 2026-10-16)
- D publishes a base set of details shared in every version of the game (every pack). GMs may use them or not.
- GMs freely create skills, techniques, spells, abilities or anything else for any NPC, enemy or player. Custom content has all the features of default content but applies only to that game session. The contract is between GM and player, and the UI reflects it.
- A skill is a name, a description, a category and a proficiency. The category is one of five predetermined categories and is organizational only. Mechanically only the skill's attribute and whether the character is proficient matter.
- Spells have no spec or schema. A player either uses a named skill or chooses to "cast magic". The GM sets the DC for whatever magic is attempted (a name or description agreed between GM and player). The result of that one roll type determines the effects.
- Sanity loss is hard-coded in the rules (how many points a player is expected to lose), but the GM can override any value before it is broadcast.
- The most important things to codify are each category and its value: reasonable defaults and mechanical codification, with naming, description and organization freeform.

### 5.2 Rulebook rulings by R
- **Canonical rulebook (2026-10-15):** `F:\My Drive\BARD\BARD Core Rulebook.pdf` (file dated Oct 20 2025; the coverage report gives a Scribus export of 2025-10-19; 41 pages, newest by date). R resolves any issue against the published physical copies. CLAUDE.md §9: the PDF is the default reference, the text version a fallback.
- **Example operations (2026-10-15):** Cinder, Nightfall and No Place Like London are narrative only. London has example checks for players, but no files fully model the engine.
- **Formats (2026-10-15):** the file and code standards on F: (Administrative Procedures Manual, Filing Code Standards, Administrative Forms) define marking and upload. Early reference files don't all comply. No new strict templates now; Typst later.
- **Pinned ruleset contents:** tied to the engine/pack caveat (section 6.2).
- **G12 (2026-10-16), verbatim:** "The handler decides Omega values. Any values actually listed will be presented as a reasonable default where available."
- **G16 (2026-10-16), verbatim:** "Proficiency Bonus is an additional dice roll". So Proficient +1d4, Expert +1d6. The flat +3/+5 in §3, §5 and §10 of the book are stale.
- **G17 (2026-10-16), verbatim:** "The stray 10 is an error in the PDF that does not appear in the printed copy. The weapon table is for damage from player weapons. Enemies and NPCs have their own individual values."
- **G17 Extreme range (2026-10-16):** the print copy says **-5** (R replied "-5" to "-5 or -4?").
- From the coverage report, resolved by rendering (not rulings): Health = END × LCK, Sanity = WIS × LCK, the category above S is Cat-Ω, the disorder table is a clean 1-6 table.

### 5.3 Still-open rulebook items
14 gaps (G1-G11, G13-G15) and the remaining decisions are in section 11.4. C5 (Occult/casting attribute) is the one remaining real text conflict, folded into G6.

---

## 6. Architecture and versioning decisions

### 6.1 Structure (agreed 2026-10-15)
- R asked for a highly modular, individually testable project, and named two preferred styles: the actor model and ECS. Victor proposed a hybrid, which R accepted by asking for the spec:
  - **ECS-style pure-Dart game domain.** Entities are an id plus immutable typed components. Systems are pure functions `(state, command) → events`, run on commands, not ticks. No archetype storage or frame loop.
  - **Coarse actors for the runtime/session layer** (one per feature area), in-process mailbox objects, not isolates. Messages are the same commands and events that cross the network.
  - **Event-sourced core:** command → events → state. Tests as "given state + command → expect events". Free session log, replay, GM monitoring, per-client event filtering for information hiding.
  - **Monorepo packages** (`engine`, `protocol`, `session`, `migrator`) shared by the main app, the companion app and functions. The engine has no Flutter, Firebase or UI imports.
- GM-gated rolls with override: `ActionRequested` (player) → `CheckRequired(skill)` (GM) → `CheckResolved` (system) → optionally `ResultOverridden` (GM). Overrides are auditable and never mutate history.
- Phone messages and per-perspective NPC panels are per-client event filtering. The companion app is just another client.

### 6.2 Engine and pack pinning (decided 2026-10-15/16; doc: `architecture/engine-pack-pinning.md`)
- Three layers: engine (semver; its major is the pack schema version), rules pack (data only, `requires: engine >= N.M`), app shell (never affects outcomes).
- The engine owns vocabulary (kinds of things and how they compute). Packs own values. Test: if it can be written by editing pack data with existing vocabulary, it's a pack change; otherwise an engine change.
- The caveat: pinning holds the pack, not the engine. Engine patches (bugs like a biased RNG) reach pinned operations. Pack minors (balancing such as 2d6 → 3d6) don't. History never changes, because the event log stores resolved results.
- An operation records pack id, exact pack version, pack schema major and the engine version last used.
- **Update defaults (R, 2026-10-15):** engine updates automatic by default, pack updates manual by default (errata included). GMs get a UI toggle to make either or both automatic or manual.
- **Seeded RNG (R, 2026-10-15):** yes, seeded and logged in the GM's engine.
- **Majors are rare (R, 2026-10-15):** a major gameplay change means republishing the physical manuals. Minor changes reach paid customers by notification and marked versions of the online PDF. R wants as little backward and cross-compatibility code in the engine as possible.
- **Structural rule changes (R, 2026-10-15):** if a rules version needs a structural change, older clients cannot download that version or later. Decouple the engine from the rest of the app so UI, server features and bug fixes ship without changing how sessions play.
- **Cross-major strategy (R, 2026-10-16): migrator only.** Each engine major knows only its own schema. A separate migrator package transforms an operation's state and pack from N to N+1; the GM runs it and reviews the result. No frozen prior engine, no old web build kept online. Consequence: in-flight operations must be migrated before continuing on a new major.
- **Compat decoding within a major (R, 2026-10-16): allowed, additive-only.** R's wording: "some new fields may be intended to eventually replace old fields, even though the old fields still accomplish the current goal. We should also probably include some form of deprecation so that users of the pack will know that some things may be changed in the future." The mechanism is proposal P11 (open).
- **Archived logs after a major (R, 2026-10-16): archive-only.** R's wording: freeze the log, "create a plain text version of the log, what would appear in the UI for the GM and the players... keep that as an additional file next to this log so that the previous Events in a session could be viewed either directly in the in-game log or in a separate archive viewer UI element. And then move forward after the operation migrated Genesis event... This should be made very apparent to the GM when they approve a change to a major version and require explicit confirmation so that they know that they're losing information that they won't be able to recover." The converted-log alternative (`architecture/archive-log-example/`) was rejected. The mechanics are proposals P12/P13 (open).
- **Web and LAN (R, 2026-10-16):** a web GM can't host LAN (browsers have no raw sockets). Accepted.

### 6.3 Verified facts behind these decisions (2026-10-15)
- Pub resolves one version per package name; distinct names like `bard_engine_v1`/`bard_engine_v2` would coexist (moot now: migrator only).
- A second Firebase Hosting site keeps an old web build permanently; preview channels expire (max 30 days). Moot now.
- Dart Cloud Functions are experimental: `firebase experiments:enable dartfunctions`, Blaze plan, Dart 3.9+, Firebase CLI 15.15.0+, only `onRequest`/`onCall` (and `onCallWithData`) deploy, may change without notice, not shown in the Firebase console, `onCall` called by URL. Rechecked 2026-10-16: still experimental.

### 6.4 The architecture spec (PR #2)
- Branch `docs/architecture`, head `fe30a99`, PR [#2](https://github.com/ShadowfeindX/BARD_Files/pull/2) open, not merged.
- Files: `docs/architecture/README.md` (index), `00-overview.md`, `01-engine.md`, `02-rules-packs.md`, `03-protocol.md`, `04-session.md`, `05-migrator.md`, `06-accounts-backend.md`, `07-apps.md`, `08-testing.md`, `09-open-decisions.md`, `verification.md` (register of verified toolkit claims, V-n tags), plus root `CHANGELOG.md`.
- Commit history: `bd3020c` first spec → `924be8b` review fixes → `62a0f34` compat decoding + web rulings (P11, W1) → `4299a15` archived-log ruling (P12, P13) → `6ad4a29` adopted backend stack (B1-B6, P14) → `fe30a99` dependency approval.
- Each step was second-agent reviewed and its findings fixed.
- Every open item it carries is in section 11.

---

## 7. Backend stack and the test Firebase project

### 7.1 Adopted stack (R, 2026-10-16: "yes, let's adopt this approach")
- **Client:** `firebase_dart` 1.6.2 (pure Dart: Auth, Realtime Database, Storage; no Firestore, FCM or App Check) on all desktop. FlutterFire only where a platform needs it (web likely). Start with one `FirebaseDartAdapter` everywhere it runs.
- **Live game data:** Realtime Database (event relay, event log, session state). Security rules decide who can write. Firestore dropped from the v1 client; a Firestore REST escape hatch is open item B1.
- **Server:** a small gateway of HTTPS-only Dart Cloud Functions (experimental): badge custom tokens, custom claims/roles, payment webhooks, store receipts, push for mobile/web, pack publishing helper. No Cloud Run gateway.
- **Admin gap:** `firebase_admin_sdk` 0.5.6 has no Realtime Database admin. Default: client writes under rules (GM client writes members after a join request; moderators copy archive entries). Alternatives: RTDB REST with a service-account OAuth token (probe 8.1b) or a Node function (R's approval). Unverified lead: `firebase_admin` (appsup.be, publisher of `firebase_dart`) may cover RTDB admin.
- **Dependencies approved by R (2026-10-16):** `firebase_admin_sdk` 0.5.6 (Auth incl. createCustomToken and setCustomUserClaims, Messaging, Storage, App Check, Firestore, Functions, Security Rules; no RTDB) and `firebase_functions` 0.8.0.
- **Offline:** `firebase_dart` persists query results, not writes, so `session` keeps its own outbox and local cache (sembast proposed), replayed as requests on reconnect; the GM stays canonical.
- **Per OS:** Windows and Linux get in-app notifications only (RTDB `/users/$uid/inbox`); FCM is mobile/web. App Check: none on Linux or `firebase_dart`; Windows listed by FlutterFire 0.5.0 but not official docs. Desktop token storage is plaintext at the `FirebaseDart.setup` path unless encrypted.
- **Proposed RTDB tree (P10):** `/users/$uid` (owner rw; fixed `/users/$uid/alias` key for anonymous users so a second alias can be refused with `!data.exists()`; `/users/$uid/inbox`), `/operations/$op/requests/$uid/$push` (players write own), `/operations/$op/events/$push` (GM uid only, append-only), `/operations/$op/members/$uid` (GM client), `/operations/$op/phone/$gmInbox/$push` (members write as `from=$uid`), `/archive/pending` → `/archive/public` (moderator copies, public read), rules-pack index in RTDB with files in Storage (D edits via console). Roles via custom claims; anonymous limits via `auth.token.firebase.sign_in_provider` [unverified].
- **Limits:** 200,000 connections and about 1,000 writes/s per database; multiple databases on Blaze.
- **Payments:** not researched. Sketch: Stripe Checkout via an `onRequest` webhook setting a tier claim (or the Invertase Stripe extension, Node/Firestore); store IAP and receipt validation if tiers are sold in mobile apps.

### 7.2 What was ruled out, and why
- **FlutterFire on Linux:** unsupported; `flutterfire_desktop` archived 2026-10-01.
- **FlutterFire on Windows:** Firebase says not for production; open issue #13212 (stale Firestore token after user switch, bad for aliases); `cloud_firestore` 7.0.0 fails to link on R's PC (`LNK2001 _Avx2WmemEnabled`, MSVC 14.44). Auth works there and exposes custom-token sign-in.
- **`firebaseapis` 0.2.0** (R's suggestion, 2026-10-16): a generated REST client, repo archived 2026-03-24. No live listeners, offline cache or on-device sign-in. The probe passed on Windows (Identity Toolkit sign-in + Firestore v1 read with an ID token, HTTP 200), so it stays usable only for REST/admin-style calls.
- **Cloud Run gateway:** dropped with the adopted stack. R is not opposed to Cloud Run, but wants Firebase features used as much as possible (2026-10-16). WebSockets there cap at 60 minutes and bill while open.

### 7.3 Test Firebase project
- Project id: `web-portfolio-2d5c2`. Realtime Database enabled at `https://web-portfolio-2d5c2.firebaseio.com` (legacy host; the `-default-rtdb` host 404s). Firestore document `games/test` = `{"test-value": "Hello from Firebase!"}`.
- An earlier project R offered was abandoned: its default Firestore database is in Datastore mode. R then said the first scratch probe had "an inconsistency with the original key" and had it deleted, so no earlier artifacts may be reused.
- Credentials (web API key, test email and password) are not recorded here. They lived only in R's messages in the threads "Verify firebaseapis for desktop" and "Backend split without FlutterFire". R must re-supply them (section 12).
- Probe results (2026-10-16), Windows (Dart 3.13.2) and native Linux (WSL2 Ubuntu, Dart 3.13.5), identical: fake-appId init, email sign-in, getIdToken (forced refresh returned the same token), signOut, anonymous sign-in, anon → email switch (new uid), authStateChanges, bad custom token → `invalid-custom-token`, RTDB read/write (~50 ms acks), listener on a second instance, offline write delivered after `goOnline`, Firestore REST read with the ID token (200). Unauthenticated REST GET returned 200 `null` (empty node, reads open). Not tested: queued write surviving an app restart, real custom token, rules on real data, long sessions, Storage, macOS/iOS/Android/web.

---

## 8. Tooling and environment setup

### 8.1 R's PC (`DESKTOP-1NG7AVU`)
- Windows 10, Git Bash, Dart 3.13.x (3.13.2 seen), Flutter 3.47.2, MSVC 14.44 (VS 2022 Community), WSL2 Ubuntu (no Dart SDK installed now).
- `C:\GAMES\BARD` is the git working copy (origin `https://github.com/ShadowfeindX/BARD_Files.git`), with `.claude/` and `.dart_context/` at the top.
- MCPs available to PC sessions: Dart/Flutter MCP (`mcp__dart__*`), Dart context MCP (`mcp__dart-context__*`), Google Developer Knowledge MCP. The Dart MCP sometimes drops with "Connection closed"; restart the session.
- Developer Knowledge MCP on the PC: entry in `C:\Users\R\.claude.json` under `projects["C:/GAMES/BARD"].mcpServers["google-developer-knowledge"]`, transport http, URL `https://developerknowledge.googleapis.com/mcp`, header `X-Goog-Api-Key` (value in that file; never print or copy it). This is R's local machine config, so it survives the account move unless R removes it.
- Optional, never done: a repo `.mcp.json` using `${DEVELOPERKNOWLEDGE_API_KEY}` for every PC session in `C:\GAMES\BARD`. R didn't ask for it; skip unless asked.

### 8.3 PC state captured 2026-10-18 (read-only survey from a Remote Control session in `C:\GAMES\BARD`)
- **Main checkout** `C:\GAMES\BARD` is on branch `docs/rules` @ `d124e15` (tracks `origin/docs/rules`), not `main`. Only untracked item: `.dart_context/index.json` (1 KB, empty file list, generated 2026-10-15). No uncommitted changes. Stash empty. Origin `https://github.com/ShadowfeindX/BARD_Files.git`.
- **Top level:** `.claude/` (`settings.json`, `worktrees/`), `.dart_context/`, `.git/`, `CLAUDE.md`. Nothing else.
- **Local branches:** `main` 5fdb4a2, `docs/rules` d124e15, `docs/architecture` fe30a99 (in sync with origin), plus seven `claude/*` branches (`charming-kapitsa-709c70`, `determined-kepler-c93900`, `determined-rhodes-c44287`, `focused-torvalds-a7f90e`, `friendly-dirac-0e3652`, `strange-dubinsky-810205`, `sweet-poincare-c3581a`). All seven `claude/*` branches sit at 5fdb4a2 with no upstream and no unique commits, so they are disposable.
- **Worktrees** under `C:\GAMES\BARD\.claude\worktrees\`, all clean: six at 5fdb4a2. `determined-rhodes-c44287` has `docs/architecture` @ fe30a99 checked out, and it is the architecture spec agent's worktree. **Nothing exists only locally;** everything is pushed.
- **`reference/` does not exist.** No reference files have been copied yet. The rule in CLAUDE.md §6 (copy into `reference/`, with the source path noted in its README) still applies when the first copy happens.
- **`.claude/settings.json`** (repo and every worktree) is `{"permissions":{"deny":["PowerShell"]}}`. There is no `.mcp.json` in the repo.
- **`C:\Users\R\.claude.json`:** project scope `C:/GAMES/BARD` has exactly one MCP server, `google-developer-knowledge`, type `http`. There are no user-scope MCP servers, and the other BARD project entries have none. The survey did not re-read the URL or header, because auto mode blocked that as credential exploration. The URL and header in 8.1 come from the 10-16 setup thread. If the entry is lost, recreate it as an http MCP server named `google-developer-knowledge` at project scope, with the key from R. The dart, dart-context and dart-flutter MCPs that PC sessions see come from plugins or another scope, not from this project entry.
- **WSL2:** distros `Ubuntu` (default, v2, systemd on, default user `r`) and `Unsloth-Engines-7a973047`. **There is no Linux Dart SDK in WSL.** The SDK R approved on 10-16 was a one-off for the probes and was deleted afterwards. `which dart` in WSL resolves to the Windows SDK through PATH interop (`/mnt/c/Users/R/flutter/3.44.8/bin/dart`), and fails with `$'\r': command not found` (CRLF in `shared.sh`). If WSL Dart is needed, ask R first, since the 10-16 approval was one-off. Then install a native Linux SDK inside WSL and put it ahead of the interop path.
- **Windows toolchain (Git Bash):** Flutter 3.47.2 stable (framework d3b14c8769, 2026-08-26), Dart 3.13.2, DevTools 2.60.0, git 2.47.0.windows.2. The SDK lives in `C:\Users\R\flutter\3.44.8\`. That folder name is stale; the contents are 3.47.2. Flutter reports that an upgrade is available.

### 8.2 Cloud threads
- Old cloud environment: `env_01P1argaTg1xHiXpmaWFSBHq` (the project's default). It held the env var `DEVELOPERKNOWLEDGE_API_KEY`. It belongs to the old account; the new account needs its own (section 12).
- How cloud agents call the API (never print the key):
  ```bash
  curl -s -X POST "https://developerknowledge.googleapis.com/v1:answerQuery?key=$DEVELOPERKNOWLEDGE_API_KEY" \
    -H "Content-Type: application/json" -d '{"query": "How do I create a BigQuery dataset?"}'
  curl -s "https://developerknowledge.googleapis.com/v1/documents:searchDocumentChunks?query=BigQuery&key=$DEVELOPERKNOWLEDGE_API_KEY"
  ```
  A search hit's `parent` can be fetched with `GET https://developerknowledge.googleapis.com/v1/<parent>?key=...`.
- Test: 2026-10-16 18:18, both calls returned HTTP 200 from a cloud thread.
- Network policy R set on the old environment: Firebase hosts allowed. Needed: `developerknowledge.googleapis.com`, `firebase.google.com`, `identitytoolkit.googleapis.com`, `securetoken.googleapis.com`, `firestore.googleapis.com`, `*.firebaseio.com` and `*.firebasedatabase.app` (RTDB), plus pub.dev and GitHub. A running container may not pick up a policy change; new threads do.
- Cloud containers have no Dart SDK by default, so Dart work runs on R's PC.
- The coordinator's cloud session can't load the Dart MCP or write library files; Agent workers or cloud thread sessions write them.
- Option A (untested, optional): a claude.ai custom connector for Developer Knowledge using a Google OAuth Web client with redirect `https://claude.ai/api/mcp/auth_callback`, URL `https://developerknowledge.googleapis.com/mcp`, scope `https://www.googleapis.com/auth/devprofiles.full_control`.

---

## 9. Thread-by-thread history

Every thread in the old project, oldest first. "Waits on" is the state on 2026-10-18.

| # | Thread (date) | Purpose | Final state and result | Pending / waits on | Outputs |
|---|---|---|---|---|---|
| 1 | Verify Dart MCP on desktop (10-15) | Haiku check of the Dart/Flutter MCP, Dart context MCP, SDKs and git remote on R's PC | Done, resolved. Both MCPs available; origin is BARD_Files; repo was empty. R: "You may consider your task complete." | Nothing | None |
| 2 | Commit rules doc and PowerShell ban (10-15) | Write R's edited CLAUDE.md and the PowerShell deny, open a PR | Done, resolved. Auto mode blocked creating `main` ("Git Destructive"); R pushed `bbb8e9b chore: initial commit`. `docs/rules` → `d124e15`; PR #1 opened via the GitHub API (no `gh` on PC), body rewritten to changelog-only, merged by R (merge commit `5fdb4a2`). | Nothing | `CLAUDE.md`, `.claude/settings.json`, PR #1 |
| 3 | Inventory example operations and file formats (10-15) | Read-only Sonnet inventory of F: and E: | Done, resolved. Found 12 forms (B-07, B-08, B-12, B-13, P-01, P-23, S-09, S-31, M-44, E-01, E-17, I-01), CFN/ARN/form-code schemes, both operations, rulebook versions. Its questions were answered by R in the project chat (section 5.2). Details in 9.1. | Nothing | Report in thread (summarized in 9.1) |
| 4 | Verify Dart package and Firebase Hosting facts (10-15) | Haiku check of two-engine packages, Hosting multi-site, Dart Functions | Done, resolved. Confirmed, partly confirmed, corrected (section 6.3). R then chose migrator only. | Nothing | None |
| 5 | Architecture spec (10-16) | Opus RC session writing the spec on `docs/architecture` | Open, blocked on R. Six commits to `fe30a99`, each reviewed. PR #2 open. | R: P1-P14, W1, B1-B6, the 09 decisions, concerns 3-7, and the architecture review R wants to do with Victor. Spec agent was told: no changes until R rules; re-check V-24/V-26/V-27 when the Dart MCP reconnects (done at fe30a99). | Branch `docs/architecture`, PR #2, `CHANGELOG.md` |
| 6 | Review architecture spec (10-16) | Second-agent review of `bd3020c` | Done. 8 spec fixes (applied at `924be8b`) and 4 rulings for R (compat decoding, archived logs, web LAN, desktop Firebase), all since ruled. Session ended 10-16. | Nothing | Findings in thread |
| 7 | Example archived log migration (10-16) | Build an example log and its converted version so R could rule | Done, resolved. R chose archive-only; this converted approach is the rejected one. | Nothing | `architecture/archive-log-example/` (4 files) |
| 8 | Rulebook coverage report (10-16) | Full report of what the Oct 2025 PDF covers and lacks; then updated under R's rules model; then the gaps file for D | Open, review-ready. 41 gaps → 17 after R's model → 14 after R resolved G12, G16, G17. Gaps file rewritten in plain language for D. | R: reviewing the report and the R decisions. D: reviewing `rulebook-gaps.md` (R passes it on). | `rulebook/rulebook-coverage-report.md`, `rulebook/rulebook-gaps.md` |
| 9 | Verify firebaseapis for desktop (10-16) | Check R's suggested `firebaseapis`, then probe it on R's PC | Done, resolved. Archived REST client; probe passed on `web-portfolio-2d5c2` (an earlier project failed: Firestore in Datastore mode). Scratch deleted on R's order ("Delete it"). | Nothing | Probe results (section 7.2) |
| 10 | FlutterFire desktop deep dive (10-16) | R's request: what works with FlutterFire on Windows/Linux, what `firebaseapis` is good for, what a Dart server can do, maintained alternatives | Done, resolved. Its three decisions were superseded by R's rulings (Linux in v1, RTDB OK, Dart Functions OK). Dart Functions confirmed still experimental. | Nothing | `architecture/firebase-desktop-deep-dive.md` |
| 11 | Developer Knowledge API access (10-16) | R: make the API usable by agents and R "immediately" | Done, resolved. Option B done: R added `DEVELOPERKNOWLEDGE_API_KEY` to the cloud environment. Option A (connector) and C (`.mcp.json`) optional, not done. | Nothing (redo env var on new account) | Setup steps (section 8) |
| 12 | Test Developer Knowledge key (10-16) | Cloud test of option B | Done, resolved. HTTP 200 on both calls, key not printed. | Nothing | None |
| 13 | Backend split without FlutterFire (10-16) | R: report on which backend parts go to a Dart server, `firebase_dart`, Cloud Functions, and what differs per OS; probes on the test project | Done, resolved. Report written, reviewed, revised. R supplied the RTDB URL, approved the inline-credential probes and the WSL2 Dart SDK (deleted afterwards). Windows and Linux probes passed. R adopted the stack. The `C:\bp` incident happened here (section 14). | Nothing | `architecture/backend-split.md` |
| 14 | Review backend split report (10-16) | Second-agent review of the report | Done, resolved. Found two errors (no RTDB admin in `firebase_admin_sdk`; anonymous upgrade must use `accounts:update`) and smaller fixes, all applied. | Nothing | `architecture/backend-split-review.md` |
| 15 | Restore file for migration (10-18) | This file | In progress at writing; delivered with the restore PR. | R: review the restore PR | `Restore.md`, `restore/library/` |

### 9.1 Inventory details worth keeping (thread 3)
- **E:\My Drive\BARD:** 41 files: Obsidian-style notes (`B.A.R.D. Supplemental Materials.md` = app feature wishlist; `The Order of the Twin Gates.md` and `UNTITLED.md` = cult lore with a Shepherd/Harvester pair "Auriel" and "Benshen" and a Pale Mother deity) and 36 PNGs.
- **Operations:** Cinder (Dec 5 1941, case file + 3 personnel files, artifact "The Catalyst", Class A) and Nightfall (Mar 14 1942, case file, agent report, 3 personnel files, Heart of Wotan, Class A). Handler Viktor Franke's team: Korrina, Von Holt, Finch. `No Place Like London.odt` (Oct 2025) is a playable adventure with checks, DCs and an Appendix A bestiary.
- **Sources:** `Administrative Forms.pdf`, `Administrative Procedures Manual.pdf` (AMP-2025-FILING-v3.2, motto "CUSTODES ARCANA ET VERUM"), `Filing Code Standards.html`, dossier PDFs, `BARD Character Sheet.html` (Oct 2025), `B.A.R.D Agent Dossier P-01-B.pdf` (Nov 2025).
- **Form conventions:** stamp "Form Approved. / Mailroom-Closet No. 29-K356.2", footer "FORM X-NN (Rev. 2025)", "FILE IN:" archive line, -A/-B pages. Code scheme `[DEPT]-[CATEGORY][SEQ]`: B Bureau Ops, P Personnel, S Supernatural Research, M Medical/Psych, E Evidence & Containment, I Intelligence, A Administrative, D Directorate; categories 00-09 core, 10-19 support, 20-29 specialized, 30-39 critical, 40-99 archive.
- **CFN:** `[YEAR]-[OP TYPE]-[LOC]-[SEQ]-[THREAT]`, e.g. `2025-I-LON-001-A`. Threat letters: C Cult/Criminal, B Beast/Blight, A Anomalous Entity, S Systemic. **ARN:** `AR-[W/M/T/L]-[YEAR]-[SEQ]`. **Clearance:** L1 Recruit, L2 Green, L3 Yellow, L4 Executive, L5 Blackbox, L6 Omega.
- **Filing timeline:** B-07 at T-24h, M-series T+6h, B-12/S-09/E-17/M-44 T+48h, supplementary T+7d.
- **Conflicts noted:** mission log B-77 (London) vs B-07 (manual); ARN year 4 digits (PDF) vs 2 (HTML); Alpha/Beta clearances unmapped to L1-L6; no standalone NPC or artifact dossier form. Victor recommended the manual PDF as canonical for all three; R's answer was to follow the file and code standards and not design new strict templates now.
- **Rulebook versions:** `BARD Core Rulebook.pdf` (Oct 20 2025, canonical), `...Core Rulebook1.3.1.pdf` and `1.3.pdf` (internally "Beta 1.1, 9/28/25", 36 pp), `B.A.R.D. FILES.zip`, Beta 1.0 `.doc`, Beta playtest adventure `.doc`, `BARD Files V2.1.txt` (Sep 23 2025), `History of B.A.R.D..txt` (lore). F: also has old HTML tools (Handler Dashboard, Character Sheet, database UI).

---

## 10. Library index

All files from the old project library (`/mnt/project-files/`), copied with paths preserved under `restore/library/`.

| Path | What it is |
|---|---|
| `architecture/engine-pack-pinning.md` | Engine vs pack versioning: three layers, vocabulary vs values, change classes, grey areas, what an operation records, migrator only. All three of its decisions are marked decided. |
| `architecture/archive-log-example/README.md` | Explains the example of converting an archived log from engine schema 1 to 2, with the seven change patterns and the cost of a required field old events never recorded. This approach was rejected by R (archive-only instead). |
| `architecture/archive-log-example/schema-1.log.jsonl` | Example GM-side log under schema 1 (12 events). Placeholder content. |
| `architecture/archive-log-example/schema-2.log.jsonl` | Same history converted to schema 2 (13 events, genesis first). Placeholder content. |
| `architecture/archive-log-example/migration-report.json` | What the migrator would show the GM: transformed, unchanged, needs decision. |
| `architecture/firebase-desktop-deep-dive.md` | FlutterFire on Windows/Linux, pure-Dart alternatives, `firebase_admin_sdk` server capabilities, mapping of needs, the `firebaseapis` probe. Its decisions were superseded by R's rulings. |
| `architecture/backend-split.md` | The adopted backend report: probe evidence on Windows and Linux, component split table, why RTDB, Dart Functions fit, per-OS differences, recommendation, open probes 8.1-8.8. |
| `architecture/backend-split-review.md` | Second-agent review of the backend report (review findings labelled W1-W5 inside that file, unrelated to spec open item W1; all applied). |
| `rulebook/rulebook-coverage-report.md` | Full rulebook coverage report: canonical content, the five flagged conflicts (C1 resolved by R, C2-C4 resolved by rendering, C5 open), further inconsistencies C6-C15 (none resolved, owner D/R), gaps G1-G17 (section 6.3 maps the original 41 gaps to the 17) (G12/G16/G17 resolved), engine alignment notes, 1.3.1 cuts, pack readiness, 21 decisions, canonical values appendix. |
| `rulebook/rulebook-gaps.md` | Plain-language version of the 14 open gaps for D, with page numbers and a possible answer each. R passes it to D. |

The repo also holds the spec on `docs/architecture` (section 6.4) and `CLAUDE.md` on `main`.

---

## 11. Open decisions awaiting R or D

Recommendation marked **Rec**. Nothing below is decided.

### 11.1 Spec proposals P1-P14 (R) — `09-open-decisions.md`
| # | Proposal | Rec |
|---|---|---|
| P1 | Extra packages `content_core` (data), `backend` (Firebase adapters), `ui_kit` (shared widgets) | Approve |
| P2 | Pub workspace monorepo layout `packages/` + `apps/` | Approve |
| P3 | Rules packs as JSON files with a manifest | Approve |
| P4 | Data-only dice expressions and formulas, no scripting | Approve |
| P5 | Engine-owned PRNG instead of `dart:math` `Random` | Approve (needed for seeded, logged, portable RNG) |
| P6 | Hand-written JSON codecs, no codegen | Approve (CLAUDE.md §10) |
| P7 | Actors as single-threaded mailbox objects, not isolates | Approve |
| P8 | Migrator works on frozen JSON schemas (archive-only part already ruled) | Approve |
| P9 | Badge sign-in via a Dart Cloud Function minting a custom token | Approve |
| P10 | RTDB model and rules (per-audience branches, write-once logs, fixed anonymous alias key), backend port with three adapters, three Firebase environments | Approve, then prototype rules (probe 8.6) |
| P11 | Deprecation record (`since`, `replacedBy`, `removeIn`, `note`) on engine schema and pack entries; warnings only within a major; `replacedBy` feeds the next migrator step | Approve (implements R's compat ruling) |
| P12 | Text log written during play, one variant per perspective (GM, public, redacted, per alias), stored with each event batch plus a head snapshot; `textlog` message; archive viewer; genesis `archives` list; new op id with seq restart; per-audience RTDB read rules | Approve (implements R's archive ruling without an old engine) |
| P13 | Migration confirmation: dedicated warning screen; tick "cannot be recovered" and type the operation name | Approve |
| P14 | Dart Function set (badge login, role claims, payment webhook, store receipts, push, pack publishing helper) and in-app inbox `/users/$uid/inbox` as push substitute on Windows/Linux | Approve |

### 11.2 Decisions in 09 (R)
| # | Decision | Options | Rec |
|---|---|---|---|
| 09-1 | State management | A Flutter `ChangeNotifier`/`ValueNotifier` + `ListenableBuilder`; B `provider`; C `riverpod` 3.4.3; D `bloc`/`flutter_bloc` | A: no dependency, matches official docs; add B later if DI hurts |
| 09-2 | Routing | A `Navigator` only; B `go_router` 18.1.0; C raw `Router` | B: deep links and web history are needed |
| 09-3 | Persistence | A `sembast` 3.9.0 + `sembast_web`; B `drift` (codegen); C `hive_ce`; D Firebase cache only | A, behind `EventStore` + `KeyValueStore` |
| 09-4 | Networking build order | Transports: in-process, LAN (`dart:io` WebSocket + `web_socket_channel`, `bonsoir` discovery), RTDB relay (fixed), P2P (`flutter_webrtc`) | In-process → LAN → RTDB relay → P2P |

CLAUDE.md §12 also lists "code style and design" and "target platforms" as open. Platforms are now effectively set by R's rulings (all targets, Linux in v1, companion app); CLAUDE.md §8 still says "to be set by R". Rec: R confirms, then CLAUDE.md gets updated in a small PR.

### 11.3 Open items W1, B1-B6 (R)
Probe numbers 8.1-8.8 throughout this file refer to `architecture/backend-split.md` §8, not to section 8 of this file. Probe 8.8 (payments and store policy) belongs with B2.
| # | Item | Options | Rec |
|---|---|---|---|
| W1 | Disallow GM hosting on the web build entirely? | Disallow (web is player-only: join, play, phone) / Allow (relay and P2P only) | No recommendation in the spec: product call. Either is a config change. |
| B1 | Keep a Firestore database as a REST escape hatch? | Yes (needs a Firestore DB beside RTDB) / No | No, unless archive search needs it |
| B2 | Unproven probe items: 8.1 queued write surviving restart, auth-required rules on real data, token expiry; 8.1b RTDB REST from a function; 8.1c native Windows RTDB via FlutterFire `firebase_database` 13.0.0; 8.3 real custom-token sign-in; 8.4 `getIdToken(true)` refresh and claims; 8.5 anonymous upgrade via `accounts:update` keeping uid; 8.6 RTDB rules prototype; 8.7 FlutterFire Firestore link error; plus Storage, long sessions, macOS/iOS/Android/web | Approve probes / defer | Approve 8.1, 8.1b, 8.5 and 8.6 first; 8.7 only if Firestore returns |
| B3 | RTDB writes that need admin rights | Client writes under rules (default) / RTDB REST from a function / Node function / check `firebase_admin` (appsup) | Client writes under rules; probe 8.1b. Any use of `firebase_admin` (appsup) or a Node function needs R's approval (CLAUDE.md §6). |
| B4 | App Check on desktop | Rely on rules / adopt FlutterFire App Check on Windows after a check | Rely on rules; App Check isn't the gate |
| B5 | Token storage on desktop (plaintext at setup path) | Encrypt / accept | Encrypt (unverified detail; verify first) |
| B6 | Calling Dart functions from desktop | HTTPS POST with Bearer ID token and callable envelope; confirm `firebase_admin_sdk` works in the function runtime and where keys are held | Probe it; prefer keyless signing with the runtime service account |

### 11.4 Spec concerns still open (R)
Concerns 1 (Firebase on desktop) and 2 (web GM cannot host LAN) were resolved by R and are not listed here.
3. Rulebook inconsistencies: now handled through the coverage report (11.5).
4. Alias transfer approval: which GM approves? Rec: destination GM approves; source campaign notified; an alias in a running operation can't move until it ends.
5. Library verification workflow: who verifies and can it be revoked? Rec: an admin custom claim held by R and D only, revocable, verifier and date recorded.
6. Payments: no provider, product or entitlement model. Rec: research store policy (probe 8.8); sketch is Stripe Checkout `onRequest` webhook setting a tier claim. Open decision from backend-split.md §7 item 5: Stripe web checkout (or the Invertase extension) for physical goods and tiers on web; store IAP and receipt validation only if tiers are sold in mobile apps. Not researched.
7. Physical dice: not requested; `CheckResolved` can carry `source: entered`. Flag only.

### 11.5 Rulebook gaps and decisions (from the coverage report, section 9)
**R, engine modeling and print checks**
- Dec 2 (G6/C5): casting attribute. Rec: WIL for "cast magic", or the attribute of the skill the player names.
- Dec 19: per-session custom skills live in an operation-scoped pack with the same schema. Rec: yes.
- Dec 20: "cast magic" is one roll kind with no spell schema; trim `OccultSystem` in the spec. Rec: yes.
- Dec 21: every category value is GM-overridable before broadcast, recorded in the event. Rec: yes.
- Resolved: Dec 1 (G16), Dec 3 (G17), Dec 14 (G12).

**D, game rules** (also in plain language in `rulebook-gaps.md`)
| Dec | Gap | Rec |
|---|---|---|
| 4 | G1 fumble basis | The total, 25% of DC rounded down |
| 5 | G2 advantage / disadvantage | GM toggles; advantage = LCK extra d6, keep best; disadvantage keeps worst |
| 6 | G3 exploding dice | Primary d6 and damage dice explode; proficiency, assist, focus and advantage dice don't (follows the sheet, departs from p11) |
| 7 | G5 sanity values | Store min/max and roll in range; trauma DC by category; half rounds up; hazard partial = half; failed Disorder Check rolls 1d6 |
| 8 | G7 death and critical injury | Restore the 1.3.1 death pool (over END = dead); ship the six-row injury table as optional base content |
| 9 | G13 named DC labels, DC 9 | Retire labels; restate as real categories (Cat-D 7 or Cat-C 10) |
| 10 | G8 armor | Static DR = END + armor value; armor categories light 1-2, medium 3-4, heavy 5+ |
| 11 | G9 melee damage, MIN | No STR on damage; MIN is a floor |
| 12 | G10 action economy | One Major + one Minor per turn; Aim = Minor, +1; Dodge any attack, Parry melee only |
| 13 | G11 threat templates | Attack bonus and Evasion per class from the printed class skill bonus |
| 15 | G6 magic details | Sanity check on every cast; group casters pay half rounded up; focus item counts the spell's category |
| 16 | G4 / G14 | §2 assist rule plus ritual exception (gaps file also suggests capping ordinary helpers, e.g. three); single-use = once per character; Artifact Clearance = GM flag |
| 17 | G15 skills | Add Mind Shielding; Eldritch Lore INT, Vehicle Modification INT, Insight WIS |
| 18 | 1.3.1 cuts (injury table, backlash, artifact repository, forms, personnel) | Ask whether intentional; if yes, move artifacts and forms to the File Repository |

---

## 12. Things R must redo on the new account

| # | Item | Where it lived | What to do |
|---|---|---|---|
| 1 | GitHub connection | Old account's GitHub link | Connect GitHub on the new account and make sure the Claude GitHub App can reach `ShadowfeindX/BARD_Files` (push access needed). Then attach the repo to the project. |
| 2 | Cloud environment | `env_01P1argaTg1xHiXpmaWFSBHq` (old account) | Create a new default cloud environment for the project. |
| 3 | `DEVELOPERKNOWLEDGE_API_KEY` | Old cloud environment's env vars | Add it to the new environment. Use the key restricted to the Developer Knowledge API (Google Cloud Credentials). Never paste it in chat. Then have a thread run the `answerQuery` test (section 8.2). |
| 4 | Network policy | Old environment | Allow: `developerknowledge.googleapis.com`, `firebase.google.com`, `identitytoolkit.googleapis.com`, `securetoken.googleapis.com`, `firestore.googleapis.com`, `*.firebaseio.com`, `*.firebasedatabase.app`, pub.dev and GitHub (or full access). |
| 5 | Firebase test credentials | R's messages in threads "Verify firebaseapis for desktop" and "Backend split without FlutterFire" (gone after the move) | Re-supply the web API key and test email/password for `web-portfolio-2d5c2` in the thread of the next probe that needs them. Consider rotating the key, since it was posted in chat. |
| 6 | Remote Control | Old project's device approvals | Approve the PC (`DESKTOP-1NG7AVU`) for the new project, with `C:\GAMES\BARD` as default and the five reference folders. Make sure "Require trusted devices" doesn't block project Remote Control (it did once on 10-15). |
| 7 | Developer Knowledge MCP on the PC | `C:\Users\R\.claude.json` (local) | Probably survives as-is. Re-check one query from a PC session. |
| 8 | Project memory and instructions | Old project | Paste section 1.2 into the new project's memory or instructions. |
| 9 | Library | Old `/mnt/project-files/` | Copy `restore/library/` back with paths preserved. |
| 10 | `.bard` folder key | `F:\My Drive\BARD\.bard` | Still yours to handle (move out of Drive and rotate, if the key is live). Agents never open it. |

---

## 13. Pending work and next steps

1. Bootstrap (section 1.1) and account setup (section 12).
2. R's architecture review with Victor using PR #2, which R asked for before ruling on the remaining open decisions.
3. R rules on P1-P14, the four 09 decisions, W1, B1-B6 and concerns 4-7. The spec agent then updates `docs/architecture` (reviewed), and R merges PR #2 when satisfied.
4. R finishes reviewing the coverage report and rules on decisions 2, 19, 20, 21. D reviews `rulebook-gaps.md` and answers decisions 4-18. Each ruling goes into the report and comes off D's file.
5. Once the rulebook rulings land, the stale flat proficiency values (§3, §5, §10) need rewriting in the book and in the core pack data.
6. Probes from B2, once approved, on the test project (credentials re-supplied by R).
7. Small CLAUDE.md update once R confirms platforms (all Flutter targets, Linux in v1) and the other §12 items.
8. Optional, only if R asks: Developer Knowledge option A (connector) or C (repo `.mcp.json`).
9. No implementation starts until R approves it.
10. Housekeeping on the PC, for R to decide (section 8.3). The main checkout is still on the merged `docs/rules` branch. Six worktrees and seven `claude/*` branches are idle at `main`. `Restore.md` sits untracked at the top of `C:\GAMES\BARD`. Only `determined-rhodes-c44287` (on `docs/architecture`) is in use.

---

## 14. Known errors and their fixes

| Error | Cause | Fix |
|---|---|---|
| Dart MCP fails in the coordinator's cloud session | No Dart SDK in the cloud container | Expected. Dart work runs in PC sessions. |
| Dart MCP "Connection closed" mid-session on the PC | MCP server drops | Restart the session. |
| Auto mode on PC denies `git commit --allow-empty && git push -u origin main` ("Git Destructive") | Safety check on `main` | Agents never push `main`. R did it once himself. |
| `gh` not found on PC | Not installed, not an approved tool | Push the branch from the PC; open the PR from the coordinator side via the GitHub MCP. |
| Remote Control refused: "this account requires trusted devices" | "Require trusted devices" was switched on | R turned it off (10-15). Check on the new account. |
| PC session refuses inline credentials relayed by Victor | Auto mode accepts only R's own typed approval | R posts the approval (and credentials) in that thread directly. |
| PC session won't install the WSL2 Dart SDK on a relayed approval | Same | R typed "I approve the WSL2 Dart SDK install" in the thread. |
| MSBuild FTK1011 (path too long) on a Flutter Windows build in Temp | Long default Temp path | Set TEMP/TMP inside `C:\GAMES\BARD`. If still too long, stop and ask R. Never move to a short path elsewhere. |
| `C:\bp`, a scratchpad `probeA`, and Temp build leftovers created outside `C:\GAMES\BARD` (10-16) | A brief allowed "a scratch dir outside the repo tree" | R deleted them. Every brief now states the folder rule explicitly. |
| Reviewer wrote `/tmp/links_check.txt`, `%TEMP%\lk.txt`, `%TEMP%\lk2.txt` (10-16) | Reviewer brief lacked the folder rule | Deleted by the spec agent; folder rule now in every reviewer brief. |
| Safety check blocked a PC session from deleting files it created | Delete protection | Ask R to delete, or request delete permission for that folder. |
| `cloud_firestore` 7.0.0 link error `LNK2001 _Avx2WmemEnabled` on Windows | Prebuilt C++ lib vs MSVC 14.44 STL mismatch (unverified) | Firestore dropped from the client; chase only if it returns (probe 8.7). |
| RTDB 404 at `https://web-portfolio-2d5c2-default-rtdb.firebaseio.com` | No instance there | Use `https://web-portfolio-2d5c2.firebaseio.com`. |
| Firestore read failed on R's first test project | Its default database is in Datastore mode | Switched to `web-portfolio-2d5c2`. |
| `API_KEY_INVALID` (HTTP 400) on sign-in | Key pasted truncated | R re-sent the full key. |
| `auth/internal-error` from `firebase_dart` in a cloud container | Agent proxy closed the tunnel mid-exchange | Not a package bug; run probes on the PC or a fresh container. |
| Proxy 403 on `firebase.google.com` / `*.firebaseio.com` from cloud | Network policy | R allowed the Firebase hosts; a running container may need a new thread to pick it up. RTDB also needs `*.firebasedatabase.app`. |
| Developer Knowledge 403 right after a session connected | Transient during connection | Retry once; it returned 200. |
| Thread replies say a PC session got a message it never received | Thread Claude can't message an RC session directly | R types into that thread, or Victor relays through the session's own thread. |
| GitHub API shows PR #1 as `merged: false, state: closed` | Listing field quirk; `main` contains merge commit `5fdb4a2` | Treat PR #1 as merged. |

---

## 15. Repository state (2026-10-18)

- `main`: `bbb8e9b chore: initial commit` → `d124e15 docs(rules): add project rules and deny PowerShell tool` → `5fdb4a2 Merge pull request #1`. Contains `CLAUDE.md` and `.claude/settings.json` only.
- `docs/rules`: `d124e15` (merged; can be deleted by R).
- `docs/architecture`: head `fe30a99`, PR #2 open, title "docs: architecture specification", not merged.
- `restore/migration-2026-10-19`: this file and `restore/library/`, PR to `main` open for R.
- `ShadowfeindX/bard` is an older repo, not used.
