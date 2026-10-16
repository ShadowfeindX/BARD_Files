# 08. Testing

Every package is testable on its own, with in-memory implementations of everything it depends on. A task is done only when `flutter analyze` and `flutter test` pass (CLAUDE.md §8).

## Engine

- **Decide tests** per system: *given* a state built from a small event list, *when* a command with a scripted RNG (fixed faces), *then* exactly these events (or this rejection).
- **Evolve tests** per event: *given* state, *when* event, *then* state.
- **Replay invariant:** for recorded logs, `replay(events)` equals the state the host held after producing them.
- **Rulebook examples as tests.** The worked examples in §2 (Agent Hall, Agent Vale, Agent Grimm) become tests once the proficiency question in [01-engine.md](01-engine.md#rulebook-gaps-found-while-writing-this) is ruled on. They pin the engine to the book.
- **Pack validation tests:** valid core pack loads; each class of error (unknown key, missing reference, wrong `engineApi`) fails with a clear message.
- **RNG tests:** known seed produces a known sequence on both native and web test runs (guards against the web number differences in [V-14]).

## Protocol

- Round-trip encode/decode for every message, command and event.
- **Fixture files** per protocol and engine version (`test/fixtures/`): old encoded messages must keep decoding within the same major.
- Version-negotiation table tests (every `refused` reason).

## Session

- Host + N participants wired with an in-memory transport and in-memory store, driven by a fake clock.
- Scenarios: duplicate requests roll once; out-of-order frames are applied in seq order; a participant that misses events resyncs; visibility filtering delivers the right subset to each perspective; a crashed host reopens from store with identical state; authorization refuses anonymous hosting.
- A **transport contract test suite** that every real transport (LAN, P2P, relay) must pass, so adding a transport means implementing an interface and running the same suite.
- An **event-store contract test suite** for whichever persistence option R picks.

## Migrator

- Fixture pairs per step (N in, N+1 out), including "needs decision" cases.
- Newest step only: output loads and folds in the current engine.

## Apps

- View-model unit tests with fake repositories.
- Widget tests for views with behavior (dice breakdown, check panel, phone thread).
- Integration tests for main flows (host, join, request → check → result) using the in-memory transport.

## Backend

- Security-rules tests and `backend` adapter tests against the Firebase Local Emulator Suite [V-19].
- `apps/server` tests with the shared protocol fixtures.

## Continuous integration (Proposed)

1. `dart format` check, failing on unformatted files (style rule in CLAUDE.md §8).
2. `flutter analyze` for the whole workspace.
3. Tests per package.
4. Dependency-rule check: fail if any `pubspec.yaml` imports a package its layer may not ([00-overview.md](00-overview.md#dependency-rules)).
5. Pack validation of `content_core`.
