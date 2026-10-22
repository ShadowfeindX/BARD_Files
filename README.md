# The B.A.R.D. Files

A Flutter application for playing *The B.A.R.D. Files* tabletop RPG remotely. It has two experiences: a **GM experience** (host an operation, run the world, create and monitor NPCs) and a **player experience** (interact with the GM, the game and the world as immersively as a 2D screen allows).

The game rules live in a pure-Dart engine driven by data packs, so the rules can be tested and reused by both the GM and player apps, and content can be edited without touching Dart.

**Status:** under active development. The current build is a one-device demo (GM console, player dossier and table panel on one screen) running on the provisional example rules pack. Nothing is released yet.

## Repository map

| Path | What it is |
|---|---|
| `apps/bard` | Main app (GM and player). Windows and Linux desktop. |
| `apps/companion` | Phone companion app (Android, player first). |
| `apps/functions` | HTTPS-only Dart Cloud Functions. |
| `packages/engine` | Pure-Dart game engine: rules computation (commands, events, state, dice, rules-pack loader), no I/O. |
| `packages/protocol_envelope`, `packages/protocol` | Wire envelope and the codecs between engine messages and the wire. |
| `packages/session` | Actors, operation loop, transport and store interfaces, Rng adapter. |
| `packages/migrator` | Transforms saved operations between engine major versions. |
| `packages/content_core` | The default rules pack as data (`assets/`). |
| `packages/backend` | Flutter and Firebase adapters behind the session and app interfaces. |
| `packages/ui_kit` | Shared widgets, theme and perspective panels. |
| `tool/` | Repository checks and scripts run by CI. |
| `firebase/` | Realtime Database rules and their emulator checks (not a workspace member). |
| `docs/architecture/` | The design specification. Start at its `README.md`. |
| `docs/developer-guide/` | Setup, architecture-by-package and how to add content and features. |
| `CHANGELOG.md` | Every merged change. |

The repository is a pub workspace: the root `pubspec.yaml` lists every member, and `flutter pub get` at the root resolves them all.

## Build, test and debug

### Toolchain

Flutter **3.47.7** (stable, Dart 3.13.5), pinned in `.flutter-version`. Install it from Google's storage:

```bash
curl -sSfLO https://storage.googleapis.com/flutter_infra_release/releases/stable/linux/flutter_linux_3.47.7-stable.tar.xz
tar -xf flutter_linux_3.47.7-stable.tar.xz -C ~
export PATH="$HOME/flutter/bin:$PATH"
```

On Windows use the matching `windows` archive. Use a bash shell (Git Bash on Windows) for every command below. More detail: [docs/developer-guide/setup.md](docs/developer-guide/setup.md).

### Setup and checks

Run from the repository root.

```bash
flutter pub get          # resolve the whole workspace
bash tool/build_pack.sh  # generate the shipped rules pack (git-ignored); needed before analyze, run or test
bash tool/check_all.sh   # CI's checks: format, analyze, dependency rules, exact pins, pack check, tests (web test run below is separate)
```

Individual steps:

```bash
dart format --output=none --set-exit-if-changed .
flutter analyze
dart run tool/bin/check_dependency_rules.dart
dart run tool/bin/check_pins.dart
bash tool/build_pack.sh --check     # fails if the generated pack is missing or stale
```

### Tests

```bash
bash tool/test_all.sh                              # every member that has a test/ folder
(cd packages/engine && dart test)                  # one pure-Dart package
(cd apps/bard && flutter test)                     # one Flutter package (includes flow tests on a real host)
(cd packages/engine && dart test -p node)          # web (Node) run; CI also does this for packages/session
bash firebase/run_rtdb_rules_test.sh               # Realtime Database rules against the emulator
```

The rules test needs Java and `firebase-tools` (`npm install -g firebase-tools`). It runs fully offline against the emulator, with the `demo-bard` project id, and prints one PASS or FAIL line per check.

Validate a rules pack (build the pack first with `bash tool/build_pack.sh`):

```bash
(cd packages/engine && dart run engine:validate_pack ../content_core/assets/generated/example-core)
```

### Run and build the app

```bash
cd apps/bard
flutter run -d linux      # or: flutter run -d windows
flutter build linux       # or: flutter build windows
```

Desktop builds need each platform's Flutter toolchain (on Linux: clang, cmake, ninja, pkg-config and the GTK 3 development headers; on Windows: Visual Studio with the C++ desktop workload). Run `flutter doctor` to see what is missing. The web build is player-only by design but `apps/bard` is not configured for web yet.

### Debugging notes

- **Stale or missing pack.** Analyzer warnings about missing asset folders, or a pack-check failure, mean the generated pack is missing. Re-run `bash tool/build_pack.sh`. Edit the source in `packages/content_core/assets/example-core/`, never the generated copy.
- **Pending values.** A `null` in a pack means the value is not decided yet. The loader reports it as a warning and the feature that needs it stays off.
- **Reproducible dice.** The demo uses a fixed seed, so every launch rolls the same dice. Engine tests use a scripted RNG.
- **Hot reload and the Flutter inspector** work as usual under `flutter run`; use `flutter run -v` for verbose logs.
- **Emulator.** `firebase/firebase.json` starts the Database emulator on `127.0.0.1:9000`. Proxy environment variables are cleared by the script because they would intercept the localhost calls. Emulator logs (`database-debug.log`) are git-ignored.
- **Dependency failures.** `check_pins.dart` fails on any non-exact external version; `check_dependency_rules.dart` fails when a package imports outside its layer. See [setup.md](docs/developer-guide/setup.md#adding-or-changing-a-dependency).

## Contributing

- **Branches.** Never push directly to `main`. Work on a branch with one of these prefixes and a descriptive name (for example `feature/dice-roller`):
  - `feature/` code that adds or changes a major feature or UI element
  - `refactor/` reorganizes files or code without changing behavior
  - `bugfix/` fixes a defect, or a mismatch between the design and the implementation
  - `docs/` specification and documentation
  - `probe/` throwaway verification code, never merged
- **Commits.** Small and focused: `type(scope): summary` where type is `feat`, `fix`, `refactor`, `test`, `docs` or `chore`.
- **Quality bar.** `bash tool/check_all.sh` must pass: formatted, zero analyzer warnings, tests green. Public APIs get `///` doc comments. Domain tests accompany engine changes; widgets with behavior get widget tests.
- **Documentation.** Update `docs/developer-guide/` in the same PR as the change it describes, and add an entry to `CHANGELOG.md`.
- **Dependencies.** A new package is proposed to the repository owner with its purpose and alternatives and is added only after approval, pinned to an exact version.
- **Game content.** The rulebook is the source of truth. Do not invent rules, stats or lore; report gaps. Keep rules data in pack files under `assets/`, separate from code.
- **Review.** Every change gets a second review before it goes to the owner: the diff against the specification, plus analysis and tests where there is code. Address or answer every finding.
- **Pull requests.** The owner approves and merges every PR. Titles are descriptive (with the version when there is one). The body is a changelog of the change itself, in this shape, omitting sections that do not apply:

  ```
  ## Short title of PR

  ### Major Item #1
  - additions and changes

  ### Changes
  - small changes

  ### Bug Fixes
  - fixes

  ### Known/Open Issues
  - known issues
  ```

- **Releases.** A release combines all PR descriptions since the previous release into one description in the same format, and is tagged with its version number.

## Further reading

- [docs/architecture/README.md](docs/architecture/README.md): the design specification and decision record
- [docs/developer-guide/README.md](docs/developer-guide/README.md): developer guide
- [CHANGELOG.md](CHANGELOG.md): what has changed
