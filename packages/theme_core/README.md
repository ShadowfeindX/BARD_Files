# theme_core

Pure-Dart theme model (no Flutter, no dependencies). See `docs/architecture/07-apps.md` (Themes and player appearance settings).

- `ThemeCodec`: decodes and validates theme files (all problems at once, with JSON paths; invalid files are rejected, never repaired) and encodes documents.
- `ThemeResolver`: own value, base chain, fallback built-in; loop, depth and missing-base checks; `flatten`.
- `base_rules.dart`: the eligible-base rule (a base is a built-in, a theme whose base is a built-in, or a theme with no base; chains are at most two links), the import and Replace checks, and `flattenedDependants` for "Flatten them first".
- `applyAppearance`: the player's setting (System follows OS brightness, missing theme or variant handled without overwriting the stored setting).
- `themeTokens`: the token registry (42 tokens in set 1; only `highlight` and `sceneTint` accept `#RRGGBBAA`).
- `ThemeLimits`: the import size and chain depth safeguards (Proposed, T3), passed in, not hard-coded.

## Editing the built-in themes

`assets/themes/{phosphor,manila,night-desk}.json` are hand-edited. Change a `#RRGGBB` value and run `bash tool/check_all.sh` (or `cd packages/theme_core && dart test`). The tests check that every variant has all 42 tokens, that `windowEdge` reaches 3:1 against `desk`, `window` and `windowRaised`, that chip text reaches 4.5:1, and that each file matches the canonical encoding (key order, two-space indent). `ui_kit` loads the files through the Flutter asset bundle and passes the text to `ThemeCodec.decode`.

Not built yet: effect-safety substitution, "Add missing colours", CIEDE2000 and colour-vision advisories (all wait on T4 or later rows).

Behaviour choices the spec does not state: name cleaning also removes LRM, RLM and ALM marks (stricter than 'bidi overrides'); `flatten` of a derived theme records its fallback built-in as `copiedFrom` so the fallback does not change; a theme that only leads into a loop (not a member) resolves as loop-flagged using the loop member's own values.
