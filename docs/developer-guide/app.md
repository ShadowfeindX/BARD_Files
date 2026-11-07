# The bard app

`apps/bard` is the GM and player app. This page covers the D demo slice: one device, all panels on screen.

## Layout

| Folder | Holds |
|---|---|
| `lib/data/models.dart` | Plain display data: `AgentSheet`, `ActionRequestItem`, `ReviewItem`, `LogEntry` (`TextEntry`, `RollEntry`), skill and difficulty options |
| `lib/data/services/episode_service.dart` | The interface view models use. Reads are `signals_flutter` signals already filtered for one perspective; commands return `Future<void>` |
| `lib/data/services/session_episode_service.dart` | The real service: an `EpisodeHost` in one-device mode over the shipped pack. Logs are built per perspective from the stored events and text-log variants (`deliveryFor`, `projectFor`) |
| `test/support/fake_episode_service.dart` | Test-only in-memory stand-in with scripted dice, used by widget tests of the UI alone. Its fixture arithmetic exists only there |
| `lib/data/protocol_engine_codec.dart` | `EngineCodec` over the `protocol` codecs. State snapshots are not decoded yet |
| `lib/data/pack_assets.dart` | Reads the generated pack from the asset bundle |
| `lib/ui/console`, `dossier`, `table`, `home` | GM console, player dossier, table panel, and the one-device screen that shows them side by side |
| `lib/data/appearance_repository.dart` | `AppearanceRepository`: where the player's theme and variant are kept (client-side only). The in-memory version holds them for the life of the process |
| `lib/app/` | `composition.dart` (the one place services are built) and `routes.dart` (`/` all panels; `/gm`, `/player/:agentId`, `/table` for a second window) |

## Rules

- View models forward intents and never compute outcomes; every number shown comes from the engine through the service.
- A held consequence (the GM review gate) appears only in the GM's review tray. The player's log gets the line after the GM confirms, without the `overriddenFrom` detail.
- GM notes are kept in the service only: the engine has no GM-note event yet, so they are not stored or replayed.
- The two demo agents, their score spread and skills are demo data created through `CreateAgent`; the creation limits come from the pack.

## Running

```bash
bash tool/build_pack.sh        # the pack is generated, not committed
cd apps/bard && flutter run -d linux   # or -d windows
cd apps/bard && flutter test           # includes the flow tests on a real host
```

## Look and appearance

The app shell is themed fixed panels on the one-device layout. `main.dart` loads a `ThemeController` (ui_kit) from the built-in themes and hands `controller.themeData` to `MaterialApp`; `BardApp` keeps `controller.osBrightness` current from the platform so System follows the OS. The controller outlives a new episode. **Appearance** in the app bar opens the theme and variant drop-down; the setting is saved through `AppearanceRepository`, which is in memory until the local store is wired in the composition work. Windows are `ShellWindow`; the player's dossier shows a `RecordCard` (attributes, vitals, conditions) under the action request.

- **Conditions.** The console's **Conditions** window picks an agent and a pack condition (`EpisodeService.conditions`) and sends `ApplyCondition`; the result waits in the review tray like a Sanity loss and the player sees it after the Handler confirms. Chips under the picker clear a condition the agent has (`ClearCondition`, direct). The record card lists the agent's conditions.
- **Whisper.** A stat-gated whisper the player receives stays a log line and also raises a **Whisper** alert at the top of the dossier, outside the phone, until dismissed (`TextEntry.whisper`, `DossierViewModel.whisper`).
- **Review.** While a consequence waits for the Handler, the player's view shows nothing.
- **NPC notes slot.** `ConsoleView(npcNotes: ...)` shows a widget after the whisper window. The Handler's NPC notes panel plugs in there; nothing is built for it yet.
- **Placeholder labels.** The record card's section labels (Attributes, Vitals, Conditions) are generic. The table label of the design's record card (DEC-24) is not used and no other field is shown until D decides the record's content.

## New episode

`New episode` (app bar) closes the active host, opens an empty one from the shipped pack, rebuilds the router so it restarts at `/`, and leaves the GM to add agents. One host is active at a time. The first launch still seeds two demo agents.

## Adding agents

`Add agent` in the console opens a dialog with the pack's creation limits (`EpisodeService.creationLimits`). The UI sends the scores through `CreateAgent` and shows the engine's refusal text; it checks only that each score is a whole number and leaves every rule to the engine. Note the engine currently checks only the per-attribute range, not the total points.

## Broadcast and phone

The console's **Stat-gated whisper** window builds a `Compare(op, Attr(key), Const(n))` condition from the attribute, comparison and value the GM picks (`BroadcastOp` mirrors the engine's `CompareOp`). **Preview** calls `engine.broadcastPreview` and lists each agent, whether they qualify and the score it read; it sends nothing. **Send** submits `BroadcastToQualifying`, so the engine decides again at send time. Only qualifying players get the line; the GM log names the recipients.

Phones use the ui_kit `PhonePanel`. Thread ids name the counterpart: `gm` for the Handler, `alias:<id>` for an agent's alias. The Handler's phone has one thread per agent (messages between the Handler and that alias); messages between two agents show in the GM log, not in the Handler's phone. A player's phone has the Handler and every other agent, built from the events that player may see. NPC parties (`PhoneNpc`) are not offered yet because the UI creates only player-owned agents.

## Demo data to replace

`SessionEpisodeService` seeds two agents with a score spread and `proficient` skills, and uses the fixed `demoSeed`, so every launch rolls the same dice. These are demo values, not rules; a real new-episode flow and a per-episode seed replace them.
