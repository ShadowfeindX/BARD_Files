# ui_kit developer notes

`packages/ui_kit` holds shared widgets. It depends only on Flutter and `signals_flutter` (exact pin), so widgets are tested with plain data.

- **Theme:** `BardTheme.light()` / `dark()` is a placeholder. The dossier look is designed after D's feedback; replace `theme.dart` only.
- **Dice breakdown:** `DiceBreakdownView(data: DiceBreakdownData(...))`. The app maps the engine's `CheckResolved` into this data. Every number, including group subtotals, comes from the engine; the widget does no arithmetic.
- **Perspective panel:** `PerspectivePanel<T>` shows a `ReadonlySignal<List<T>>` already filtered for one perspective. Give it a bounded height.
- **Phone panel:** `PhonePanel(threads: ..., onSend: ...)` shows `PhoneThreadData` (id, title, messages) for one viewer and calls `onSend(threadId, text)`; the app turns that into `SendPhoneMessage` and maps `phoneConversations(...)` from the engine into the data. The cap counts UTF-16 units (2,000, as the engine and relay rules); `sendDisabledReason` replaces the compose box, for accounts that may not message. The console that hosts it is row 8's.
- **Tests:** `cd packages/ui_kit && flutter test`.

- **Phone panel limits:** `PhonePanel.maxLength` defaults to the literal 2000 and the invisible-character list is a copy, because ui_kit does not import the engine. Both mirror `maxPhoneTextUnits` and `invisiblePhoneChars` in `packages/engine/lib/src/phone.dart`; change them together.
