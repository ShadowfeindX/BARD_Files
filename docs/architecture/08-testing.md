# 08. Testing

Every package is testable on its own, with in-memory implementations of everything it depends on. A task is done only when `bash tool/check_all.sh` passes (CLAUDE.md §8), which runs `flutter analyze` and the tests among its checks.

## Engine

- **Decide tests** per system: *given* a state built from a small event list, *when* a command with a scripted RNG (fixed faces), *then* exactly these events (or this rejection).
- **Evolve tests** per event: *given* state, *when* event, *then* state.
- **Replay invariant:** for recorded logs, `replay(events)` equals the state the host held after producing them.
- **Rulebook examples as tests.** The worked examples in §2 (Agent Hall, Agent Vale, Agent Grimm) are tests (`packages/engine/test/rulebook_examples_test.dart`): proficiency adds dice (see [01-engine.md](01-engine.md#rulebook-values-the-engine-uses)). They pin the engine to the book.
- **Pack validation tests:** valid core pack loads; each class of error (unknown key, missing reference, wrong `engineApi`) fails with a clear message.
- **RNG tests:** known-seed vectors for `Xoshiro128pp` (`xrandom`, pinned exactly) produce the same sequence on both native and web test runs (guards against the web number differences in [V-14]) [V-28]. The vectors live with the `session` adapter; the engine's own tests use the scripted `Rng`.
- **`var` node tests:** the supported placements evaluate with the engine-supplied value (`10 × var(newScore)`; the assistance placement is tested as built, `1d6 + var(helperSkillBonus)`, until the Assistance row in [01](01-engine.md#planned-code-changes) lands; key name open: [API-1](09-open-decisions.md#api-1-engine-and-pack-api-shapes)).
- **Review-gate tests:** a consequence batch is held and not stored or broadcast until confirmed; an edit records `overriddenFrom`; `CheckResolved` is never held or altered.

## Protocol

- Round-trip encode/decode for every message, command and event.
- **Fixture files** per protocol and engine version (`test/fixtures/`): old encoded messages must keep decoding within the same major.
- Version-negotiation table tests (every `refused` reason).

## Session

- Host + N participants wired with an in-memory transport and in-memory store, driven by a fake clock.
- Scenarios: duplicate requests roll once; out-of-order frames are applied in seq order; a participant that misses events resyncs; visibility filtering delivers the right subset to each perspective; a crashed host reopens from store with identical state; authorization refuses anonymous hosting.
- Planned: a **transport contract test suite** that every real transport (LAN, P2P, relay) must pass, so adding a transport means implementing an interface and running the same suite.
- Planned: an **event-store contract test suite** for the sembast store (and any later store).
- **Sembast crash test (hard kill, commit marker) [V-31].** Planned; no harness is in the repository yet. The probe's harness writes events + text + head in one transaction, then a commit marker in its own transaction, and is hard-killed at random points over many runs (the probe used 100 kills). On open, everything after the last marker is discarded; the test passes only if no committed batch is lost and no torn batch is visible. Run on Linux and Windows. It does not cover power loss or OS crash (not protected in v1).

## Migrator

- Planned (`packages/migrator` holds a placeholder test today): fixture pairs per step (N in, N+1 out), including "needs decision" cases.
- Newest step only: output loads and folds in the current engine.
- Planned: archive: frozen log byte-identical, text log carried over unchanged, genesis event references both; the confirmation screen cannot be passed with a single tap (widget test: single tap never confirms; the "cannot be recovered" tick and typed episode name are both required).

## Apps

- View-model unit tests with fake repositories.
- Widget tests for views with behavior (dice breakdown, check panel, phone thread).
- Integration tests for main flows (host, join, request → check → result) using the in-memory transport.

## Backend

- Security-rules tests and `backend` adapter tests against the Firebase Local Emulator Suite [V-19]. Realtime Database rules are tested in the Emulator Suite. The Firestore rules are drafted in [12-firestore-collections.md](12-firestore-collections.md) (Proposed, open: [S-7](09-open-decisions.md#s-7-firestore-collections)) and are to be tested in the Emulator Suite; the tests are still to be written (open: [S-7](09-open-decisions.md#s-7-firestore-collections)). The RTDB rules suite is `firebase/rtdb_rules_test/` with the rules in `firebase/database.rules.json` (run with `bash firebase/run_rtdb_rules_test.sh`; see `firebase/README.md`). The suite is based on probe 8.6's emulator checks (116 of 116 pass [V-38]) and covers: the GM cannot delete `meta`; a member cannot overwrite another uid's signaling; no `phoneDraft` path is accepted; no delete of `meta` or `meta/gm`; signaling by uid, refused after lock; presence writable after lock; phone messages create-only; and the post-archive clean-up [V-50]. Also covered: presence refused once archived, `meta` validation, and no signaling or phone messages for anonymous members [V-51]; no signaling reads for anonymous members, phone message shape and 2,000-character cap, `locked` never removed, and non-member text log reads [V-52]; clients (the GM included) refused when they set `meta/status` to `archived`, the text log `alias:null` read, and the phone text cap counting UTF-16 code units [V-53]. 200 of 200 pass.
- **Outbox restart test (planned).** A request queued offline survives an app restart and is replayed once on reconnect. The SDK's own queue does not survive a restart [V-40], so this test is what proves offline requests are kept.
- **Auth tests** (planned; `backend` holds a placeholder test today; against the emulator where it supports them): anonymous upgrade keeps the uid and forces a token refresh [V-39] (open: [06-O2](09-open-decisions.md#06-o2-anonymous-to-full-account-upgrade)); `EMAIL_EXISTS` and `WEAK_PASSWORD` map to user messages; a lost or wrong secure-store key ends in a clean signed-out state, not an error loop [V-44]; the keyring timeout guard fires instead of hanging [V-34].
- Planned: `apps/functions` tests with the shared `protocol_envelope` fixtures.

## Continuous integration

The workflow is `.github/workflows/ci.yml`: one job, `check`, on a Linux runner, for every pull request and every push to `main`. `bash tool/check_all.sh` runs the same checks locally in the same order ([developer guide](../developer-guide/setup.md#the-checks)). The steps are:

1. Install Flutter from Google storage at the version in `.flutter-version`, then resolve the workspace (`flutter pub get`).
2. Build the rules pack from the annotated source (`bash tool/build_pack.sh`); the generated pack is kept out of git.
3. `dart format` check, failing on unformatted files (style rule in CLAUDE.md §8).
4. `flutter analyze` for the whole workspace.
5. Dependency-rule check (`tool/bin/check_dependency_rules.dart`): fail if any `pubspec.yaml` lists a package its layer may not, under `dependencies` or `dev_dependencies`, allowing only the listed test-only exception (`migrator` → `engine`) ([00-overview.md](00-overview.md#dependency-rules)). Includes a **transitive check**: the resolved dependency graph of `apps/functions` must never contain `engine` (it depends only on `protocol_envelope`).
6. Exact-pin check (`tool/bin/check_pins.dart`): every external dependency is an exact version, which covers the pinned packages (`xrandom`, `sembast`, `hive`).
7. Pack-current check (`bash tool/build_pack.sh --check`): the generated pack is present, current and has no extra files.
8. Tests for every package that has a `test/` folder (`bash tool/test_all.sh`). Pack validation of the example pack runs here, through the engine's pack loader tests.
9. Web run of the tests: `dart test -p node` in `packages/engine` and `packages/session`.

Not yet in CI: a separate pack-validation job for `content_core` (open: [O-08-1](09-open-decisions.md#o-08-1-pack-validation-job)), and the Emulator Suite runs of the RTDB rules and the Firestore rules (the RTDB suite is run by hand with `bash firebase/run_rtdb_rules_test.sh`).
