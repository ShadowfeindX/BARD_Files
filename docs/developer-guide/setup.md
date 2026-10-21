# Setup

## Toolchain

| Tool | Version | Where it is pinned |
|---|---|---|
| Flutter (stable) | 3.47.7 | `.flutter-version` (CI reads it) and `environment.flutter` in the Flutter members (`backend`, `ui_kit`, `apps/bard`, `apps/companion`) |
| Dart SDK | 3.13.5 (ships with that Flutter) | `environment.sdk` in each pubspec |

`go_router` 18.1.1 and `app_links` 7.2.2 need Flutter 3.44 or newer, so the pin must not go lower. To move to a newer Flutter, change `.flutter-version` and the `environment` lines together, run `bash tool/check_all.sh`, and note it in `CHANGELOG.md`.

Install Flutter from Google's storage (CLAUDE.md §6). On Linux:

```bash
curl -sSfLO https://storage.googleapis.com/flutter_infra_release/releases/stable/linux/flutter_linux_3.47.7-stable.tar.xz
tar -xf flutter_linux_3.47.7-stable.tar.xz -C ~
export PATH="$HOME/flutter/bin:$PATH"
```

On Windows use the matching `windows` archive from the same storage path and add `flutter\bin` to `PATH`. Use Git Bash for every command (CLAUDE.md §6).

## First build

The shipped rules pack is generated from annotated source and is not in git: run `bash tool/build_pack.sh` (or `tool/check_all.sh`, which does) before running or testing an app. See [content_core/README.md](../../packages/content_core/README.md).

From the repository root:

```bash
flutter pub get          # resolves the whole workspace at once
bash tool/check_all.sh   # format, analyze, dependency rules, pins, tests
cd apps/bard && flutter run -d linux    # or -d windows
```

`flutter pub get` at the root writes one `pubspec.lock` for every package; commit it.

## Workspace layout

The root `pubspec.yaml` lists every member under `workspace:`. Packages follow [00-overview.md](../architecture/00-overview.md#repository-layout):

- `packages/`: `engine`, `protocol_envelope`, `protocol`, `session`, `migrator`, `content_core`, `backend`, `ui_kit`.
- `apps/`: `bard` (Windows and Linux desktop), `companion` (Android), `functions` (Dart Cloud Functions).
- `tool/`: repository checks run by CI (a member too).
- `firebase/`: RTDB rules and emulator checks. Standalone, not a workspace member.

Every member has `resolution: workspace`, depends on other members as `any`, and pins every external package to an exact version.

## The checks

`bash tool/check_all.sh` runs what CI runs, in this order:

| Step | Command | Fails when |
|---|---|---|
| Format | `dart format --output=none --set-exit-if-changed .` | a file is not formatted |
| Analyze | `flutter analyze` | any warning or info (one `analysis_options.yaml` at the root) |
| Dependency rules | `dart run tool/bin/check_dependency_rules.dart` | a pubspec lists a package its layer may not, a pubspec is not in the workspace, or `apps/functions` reaches `engine` or `protocol` transitively |
| Exact pins | `dart run tool/bin/check_pins.dart` | an external dependency is not an exact version (F5) |
| Rules pack | `bash tool/build_pack.sh` then `bash tool/build_pack.sh --check` | the generated pack (`packages/content_core/assets/generated/`, git-ignored) is missing, stale or has extra files |
| Tests | `bash tool/test_all.sh` | any package test fails |

Pack validation of `content_core` ([08-testing.md](../architecture/08-testing.md#continuous-integration-proposed), step 5) joins this list when the pack loader lands.

The CI workflow is `.github/workflows/ci.yml`. It is **Proposed** in 08 and approved as a setup decision (implementation plan, decision 5).

## Adding or changing a dependency

1. Propose the package to R with its purpose and alternatives (CLAUDE.md §6). Nothing is added before approval.
2. Re-verify the version, SDK range and platforms on pub.dev (F5).
3. Pin the exact version, with no `^`, in the pubspec of the one package that needs it.
4. If the package is new to a layer, add it to `layerRules` in `tool/lib/dependency_rules.dart` **and** to the table in [00-overview.md](../architecture/00-overview.md#dependency-rules); the two must agree.
5. Run `bash tool/check_all.sh`.

`test` is pinned at 1.31.1 on purpose: Flutter 3.47.7 pins `test_api` 0.7.12, and later `test` versions need a newer `test_api`, so the workspace would not resolve. Move it up together with the Flutter pin.

## Adding a package

1. Create `packages/<name>/` with a `pubspec.yaml` copied from a sibling of the same kind (pure Dart or Flutter), `lib/<name>.dart` and a test.
2. List it under `workspace:` in the root `pubspec.yaml`.
3. Add its rule to `layerRules` and to 00-overview.md.
4. Run `flutter pub get` and `bash tool/check_all.sh`.
