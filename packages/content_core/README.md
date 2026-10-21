# content_core

D's default rules pack, as data under `assets/`. No logic and no dependencies (`00-overview.md`, dependency rules).

## The pack in `assets/example-core/` is provisional

It is a copy of the `example-core` sample pack from the project library (source: `packs/example-core/` in the project library; its own `README.md` is kept beside it as the guided tour for D). **D's pack replaces it** once D approves the pack shape (P3, pending D); the file list, field names and values may all change then. No values were invented. The only edit to the copy is renaming the four `*Placeholder` annotation keys to start with `_` (R's ruling, below).

- A value of `null` means **pending D** (see the gaps in the library's `rulebook/rulebook-gaps.md`). The pack loader (`feature/pack-loader`, not on this branch yet) reports each one as a warning, not an error; the feature that needs the value stays off and the UI labels it as pending.
- `example-operation` (the operation-tier sample) is not part of this package.

## Annotations and the shipped pack

The files in `assets/example-core/` are the **authoring source**. They carry annotations for D and R: the keys `note`, `source`, `openItems`, `placeholder`, `gap`, any key ending in `Note`, and any key starting with `_` (R, 2026-10-21). Annotations are stripped before the pack ships (`02-rules-packs.md`, Authoring annotations).

An object that held nothing but annotations (a `{placeholder, gap, note}` marker) becomes `null`. An underscore-prefixed marker key such as `_attributePlaceholder` is removed with its value (its sibling is already `null`) and listed in the build output. That is the single pending-D signal; the loader never sees a `{}` standing in for "undecided". A `note` inside a `deprecated` record is data and is kept.

The shipped pack is **generated**, not committed:

```bash
bash tool/build_pack.sh            # writes assets/generated/example-core/ (git-ignored)
bash tool/build_pack.sh --check    # fails if the generated pack is missing, stale or has extra files
```

`content_core/pubspec.yaml` declares the generated folders as Flutter assets, so run the build before `flutter run`, `flutter build` or `flutter test` in an app. `tool/check_all.sh` and CI build it first and run `--check` before the tests. The build prints each pending-D value it set to `null` and any key that looks like an annotation but is not in the rules above (kept, for review).

Edit the source files, never the generated ones; rebuilding replaces the whole generated folder.
