# ui_kit developer notes

`packages/ui_kit` holds shared widgets. It depends only on Flutter and `signals_flutter` (exact pin), so widgets are tested with plain data.

- **Theme:** `BardTheme.light()` / `dark()` is a placeholder. The dossier look is designed after D's feedback; replace `theme.dart` only.
- **Dice breakdown:** `DiceBreakdownView(data: DiceBreakdownData(...))`. The app maps the engine's `CheckResolved` into this data. Every number, including group subtotals, comes from the engine; the widget does no arithmetic.
- **Perspective panel:** `PerspectivePanel<T>` shows a `ReadonlySignal<List<T>>` already filtered for one perspective. Give it a bounded height.
- **Tests:** `cd packages/ui_kit && flutter test`.
