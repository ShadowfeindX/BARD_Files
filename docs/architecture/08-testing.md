# 08. Testing

Every package is testable on its own, with in-memory implementations of everything it depends on. A task is done only when `flutter analyze` and `flutter test` pass (CLAUDE.md §8).

## Engine

- **Decide tests** per system: *given* a state built from a small event list, *when* a command with a scripted RNG (fixed faces), *then* exactly these events (or this rejection).
- **Evolve tests** per event: *given* state, *when* event, *then* state.
- **Replay invariant:** for recorded logs, `replay(events)` equals the state the host held after producing them.
- **Rulebook examples as tests.** The worked examples in §2 (Agent Hall, Agent Vale, Agent Grimm) are tests now: the proficiency question is ruled (additional dice, G16; see [01-engine.md](01-engine.md#rulebook-gaps-and-settled-rulings)), so they are unblocked. They pin the engine to the book.
- **Pack validation tests:** valid core pack loads; each class of error (unknown key, missing reference, wrong `engineApi`) fails with a clear message.
- **RNG tests:** known-seed vectors for `Xoshiro128pp` (`xrandom`, pinned exactly) produce the same sequence on both native and web test runs (guards against the web number differences in [V-14]) [V-28]. The vectors live with the `session` adapter; the engine's own tests use the scripted `Rng`.
- **`var` node tests:** the approved placements evaluate with the engine-supplied value (`10 × var(newScore)`, `1d6 + var(helperSkillBonus)`).
- **Review-gate tests (F2):** a consequence batch is held and not stored or broadcast until confirmed; an edit records `overriddenFrom`; `CheckResolved` is never held or altered.

## Protocol

- Round-trip encode/decode for every message, command and event.
- **Fixture files** per protocol and engine version (`test/fixtures/`): old encoded messages must keep decoding within the same major.
- Version-negotiation table tests (every `refused` reason).

## Session

- Host + N participants wired with an in-memory transport and in-memory store, driven by a fake clock.
- Scenarios: duplicate requests roll once; out-of-order frames are applied in seq order; a participant that misses events resyncs; visibility filtering delivers the right subset to each perspective; a crashed host reopens from store with identical state; authorization refuses anonymous hosting.
- A **transport contract test suite** that every real transport (LAN, P2P, relay) must pass, so adding a transport means implementing an interface and running the same suite.
- An **event-store contract test suite** for the sembast store (and any later store).
- **Sembast crash test (hard kill, commit marker) [V-31].** A harness writes events + text + head in one transaction, then a commit marker in its own transaction, and is hard-killed at random points over many runs (the probe used 100 kills). On open, everything after the last marker is discarded; the test passes only if no committed batch is lost and no torn batch is visible. Run on Linux and Windows. It does not cover power loss or OS crash (not protected in v1).

## Migrator

- Fixture pairs per step (N in, N+1 out), including "needs decision" cases.
- Newest step only: output loads and folds in the current engine.
- Archive: frozen log byte-identical, text log carried over unchanged, genesis event references both; the confirmation screen cannot be passed with a single tap (P13 widget test: single tap never confirms; the "cannot be recovered" tick and typed operation name are both required).

## Apps

- View-model unit tests with fake repositories.
- Widget tests for views with behavior (dice breakdown, check panel, phone thread).
- Integration tests for main flows (host, join, request → check → result) using the in-memory transport.

## Backend

- Security-rules tests and `backend` adapter tests against the Firebase Local Emulator Suite [V-19]. Both Realtime Database rules and Firestore rules are tested in the Emulator Suite (P10b). Held: the RTDB live-play rules and their tests wait on probe 8.6 (P10c); Firestore collections and their rules tests are still to be drafted, now that FS2 has passed.
- `apps/functions` tests with the shared `protocol_envelope` fixtures.

## Continuous integration (Proposed)

Pinned packages (`xrandom`, `sembast`, `hive`) are checked to be pinned exactly (F5).

1. `dart format` check, failing on unformatted files (style rule in CLAUDE.md §8).
2. `flutter analyze` for the whole workspace.
3. Tests per package.
4. Dependency-rule check: fail if any `pubspec.yaml` lists a package its layer may not, under `dependencies` or `dev_dependencies`, allowing only the listed test-only exception (`migrator` → `engine`) ([00-overview.md](00-overview.md#dependency-rules)). Includes a **transitive check**: the resolved dependency graph of `apps/functions` must never contain `engine` (F4: it depends only on `protocol_envelope`).
5. Pack validation of `content_core`.
