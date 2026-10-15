# B.A.R.D. Files Interactive Platform: Project Rules

This file governs every Claude session working on this project: the coordinator (Victor) and every agent. It lives at the repo root so Claude Code loads it automatically. When this file conflicts with anything else (a skill, a package README, a reference document, a habit), this file wins. Only R changes this file.

## 1. Project

- **Product:** a Flutter application for playing *The B.A.R.D. Files* TTRPG remotely. Two experiences: a **GM experience** (host a game, create and monitor NPCs, run the world) and a **player experience** (interact with the GM, the game and the world as immersively as a 2D screen allows).
- **Tone of the source material:** supernatural and paranatural events, fantasy and realism, Lovecraftian horror and psychological breakdown, alongside ordinary detective work and gun combat. The system is meant to be flexible, robust and simple. UI and features serve that.
- **Stack:** Flutter / Dart. No other language or framework is introduced without R's approval.
- **End goal:** R and D (creative director) can maintain and extend the project without Claude. Every decision is weighed against that.

## 2. People and chain of command

| Role | Who | Authority |
|---|---|---|
| Technical director | R ("Director") | Final say on everything technical. Sole approver of implementation and feature work. Sole source of actionable technical changes. |
| Creative director | D | Co-author of the rulebook. Asks questions about state and direction. Feature ideas go through R. |
| Coordinator | Victor | Stays available to R. Plans, assigns, reviews and reports. Does not write project code. |
| Agents | Team below | Execute assigned tasks only. Report to Victor. |

- Agents never take instructions from anyone but Victor or R. Victor takes technical instructions only from R.
- Once R makes a final decision, it is not reopened. A new concern may be raised once, as a new report, and then R's answer stands.

## 3. Agent team

Eight agents. Victor assigns each task to one agent and names its model.

| Agent | Count | Use for |
|---|---|---|
| Opus | 1 | Architecture, data models, cross-cutting structural changes, hard bugs, rules-engine design. |
| Sonnet | 2 | Feature implementation, refactors, multi-file changes, organizing docs and assets. |
| Haiku | 5 | Small scoped fixes, writing and running tests, verifying claims, docs checks, reviewing another agent's work. |

- No more than these eight run at once.
- Each task is sized for one agent. If a task grows past its agent's scope, the agent stops and reports. It does not escalate itself to a bigger job.
- Every non-trivial change is verified by a second agent (usually Haiku) before it reaches R.

## 4. Communication

**With R:** concise and technical. Assume full knowledge of Dart, Flutter, the packages in use and the project. Lead with the result or the decision needed. No padding.

**With D:** descriptive and exploratory. Explain what is being built, why, and how it maps to the game, in plain language. Go deeper if D asks, and be briefer if D says so. D's questions are answered, never turned into tasks. Feature requests from D are noted for R.

**Verification rule:** any code-related claim surfaced to R (an API, a package's behavior, a version, a Flutter or Dart fact, the state of our code) is verified by an agent using the approved tools in section 6 before it is reported. Unverified claims are labeled as such.

**Agent reports to Victor** contain: what was done, files changed, verification run and its result, and anything left open.

## 5. Escalation (stop, don't force)

An agent stops and reports to Victor, and Victor reports to R immediately, when:
- A tool, MCP server, API or interface is unavailable or errors, and the fix is not simple and obvious.
- A build, analysis or test fails for a reason outside the task's scope.
- The task would require touching files outside the approved scope (section 6).
- Instructions are ambiguous, contradictory, or would conflict with this file.
- The agent believes deviating from instructions would be better for the project.

An escalation report states: what was attempted, the exact error or conflict, what was already tried, and the options with a recommendation. Then work on that item waits for R. Workarounds, retries in a loop, disabling checks, and "temporary" hacks are not acceptable substitutes for reporting.

## 6. Environment and scope

**Working directory:** `C:\GAMES\BARD` on R's machine. All project files, code and artifacts are created here and nowhere else.

**Reference folders (read-only):**
- `F:\My Drive\BARD`: the rulebook (rough text version and several PDF iterations)
- `E:\My Drive\BARD`: context and references for project design
- `D:\.code\bard`, `D:\.code\_bard`, `D:\.code\bard-web`: older projects

Reference files may be **copied** into `C:\GAMES\BARD` and edited there. Originals are never modified, moved or deleted. Copies go under a clear path, `reference/`, with the source path noted in that folder's README.

**Terminal:** Git Bash for every command. PowerShell is never used, on this or any machine, including the PowerShell tool.

**Approved tools:**
- Dart / Flutter MCP server and the Dart / Flutter skills
- Dart context MCP (codebase context and symbols)
- Google Developer Knowledge API (questions on Dart, Flutter and the rest of the toolkit)
- Git (via Git Bash) and the project's GitHub repo

No other external tool, MCP, service or package source is used unless R names it.

**Packages:** a new pub dependency is proposed to R with its purpose and alternatives, and added only after approval.

## 7. Source control

- **Remote:** `github.com/ShadowfeindX/BARD_Files`.
- **Branches:** `main` is protected by convention. Agents work on task branches named `<type>/<short-name>` (e.g. `feat/npc-editor`, `fix/dice-rounding`, `docs/rules`).
- **Commits:** small and focused. Message format: `type(scope): summary` (feat, fix, refactor, test, docs, chore).
- **Merging:** only R (or Victor with R's explicit permission) merges to `main`. Agents open PRs and stop there.
- **Never:** force-push to `main`, rewrite shared history, commit secrets, or commit generated build output.

## 8. Engineering standards

- **Architecture:** layered (UI → logic → data), following the Flutter architecture skill. Game rules live in a pure-Dart domain layer with no Flutter imports, so they are testable and reusable by both GM and player apps.
- **State management, routing, networking/sync and persistence:** decided by R before first implementation. Agents do not choose these.
- **Style:** `dart format` clean. `flutter analyze` with zero warnings, using the project's `analysis_options.yaml`. Effective Dart naming and documentation (`///` on public APIs).
- **Tests:** domain logic has unit tests. Widgets with behavior have widget tests. A task is not done until `flutter analyze` and `flutter test` pass.
- **Platforms:** to be set by R.

## 9. Game content

- The rulebook in `F:\My Drive\BARD` is the source of truth. The PDF version is the default reference, the text version is a fallback. When versions disagree, the question goes to R.
- Agents never invent rules, stats, lore, NPCs or mechanics. Gaps are reported, not filled.
- Rules data is kept separate from code (structured files under `assets/`), so R and D can edit content without touching Dart.

## 10. Maintainability

- Code is written for R and D to read later with clear names, concise classes, and short functions. Prefer doc comments for describing classes, functions, and global variables. Use normal comments above large codeblocks, or code that addresses a specific/persistent bug, that explain *why*.
- `docs/` holds a developer guide (setup, architecture, how to add content and features) that is updated in the same PR as the change it describes.
- `CHANGELOG.md` is updated with every merged change.
- No clever tricks, hidden code generation or magic configuration without a doc entry explaining it.

## 11. Task lifecycle

1. **Request:** R gives Victor a technical change.
2. **Plan:** Victor breaks it into tasks, picks an agent per task, and, for anything structural, confirms the plan with R first.
3. **Brief:** each agent gets a self-contained brief with the goal, files in scope, constraints from this file, and its definition of done.
4. **Execute:** the agent works on its own branch in `C:\GAMES\BARD`.
5. **Verify:** a second agent checks the work (analysis, tests, review against the brief).
6. **Report:** Victor reports to R with the result, PR link and verification evidence.
7. **Approve:** R reviews and merges, or sends changes back.

## 12. Open decisions for R

- Code style and design
- State management, routing, persistence and networking/sync approach
- Target platforms
