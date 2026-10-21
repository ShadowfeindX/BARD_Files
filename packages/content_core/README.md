# content_core

D's default rules pack, as data under `assets/`. No Dart code and no dependencies (`00-overview.md`, dependency rules).

## The pack in `assets/example-core/` is provisional

It is a copy of the `example-core` sample pack from the project library (source: `packs/example-core/` in the project library; its own `README.md` is kept beside it as the guided tour for D). **D's pack replaces it** once D approves the pack shape (P3, pending D); the file list, field names and values may all change then. Nothing in it was invented here.

- A value of `null` means **pending D** (gaps G1, G3, G5, G9 and G15 in the library's `rulebook/rulebook-gaps.md`). The pack validator warns instead of failing, the feature that needs the value stays off, and the UI labels it as pending.
- Annotation keys (`note`, `source`, `openItems`, `placeholder`, `gap`, and any key ending in `Note`) are authoring notes for D and R. They are kept in the source files so D can see which gaps are open, and are stripped before a pack ships (`02-rules-packs.md`, Authoring annotations).
- `example-operation` (the operation-tier sample) is not part of this package.

## Stripping annotations

```bash
dart run tool/bin/strip_annotations.dart packages/content_core/assets/example-core build/example-core
```

Writes the stripped `.json` files to the output folder (other files such as the README are not copied) and prints what it found:

- Objects that held only annotations come out as `{}` and are listed ("is empty after stripping"). They mark values pending D, so they are reported rather than dropped.
- Keys that look like annotations but are not in the spec's list (for example `_note` in `strings/en.json`, or the `attributePlaceholder` wrapper objects) are listed ("kept"). The spec's list is fixed, so the tool does not strip them; whether to extend it is R's call.
- A `note` inside a `deprecated` record is data (`01-engine.md`, Deprecation) and is kept.

The stripper's own tests are in `tool/test/`.
