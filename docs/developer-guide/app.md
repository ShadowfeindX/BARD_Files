# The bard app

`apps/bard` is the GM and player app. This page covers the D demo slice: one device, all panels on screen.

## Layout

| Folder | Holds |
|---|---|
| `lib/data/models.dart` | Plain display data: `AgentSheet`, `ActionRequestItem`, `ReviewItem`, `LogEntry` (`TextEntry`, `RollEntry`), skill and difficulty options |
| `lib/data/services/operation_service.dart` | The interface view models use. Reads are `signals_flutter` signals already filtered for one perspective; commands return `Future<void>` |
| `lib/data/services/session_operation_service.dart` | The real service: an `OperationHost` in one-device mode over the shipped pack. Logs are built per perspective from the stored events and text-log variants (`deliveryFor`, `projectFor`) |
| `test/support/fake_operation_service.dart` | Test-only in-memory stand-in with scripted dice, used by widget tests of the UI alone. Its fixture arithmetic exists only there |
| `lib/data/protocol_engine_codec.dart` | `EngineCodec` over the `protocol` codecs. State snapshots are not decoded yet |
| `lib/data/pack_assets.dart` | Reads the generated pack from the asset bundle |
| `lib/ui/console`, `dossier`, `table`, `home` | GM console, player dossier, table panel, and the one-device screen that shows them side by side |
| `lib/app/` | `composition.dart` (the one place services are built) and `routes.dart` (`/` all panels; `/gm`, `/player/:agentId`, `/table` for a second window) |

## Rules

- View models forward intents and never compute outcomes; every number shown comes from the engine through the service.
- A held consequence (the F2 review gate) appears only in the GM's review tray. The player's log gets the line after the GM confirms, without the `overriddenFrom` detail.
- GM notes are kept in the service only: the engine has no GM-note event yet, so they are not stored or replayed.
- The two demo agents, their score spread and skills are demo data created through `CreateAgent`; the creation limits come from the pack.

## Running

```bash
bash tool/build_pack.sh        # the pack is generated, not committed
cd apps/bard && flutter run -d linux   # or -d windows
cd apps/bard && flutter test           # includes the flow tests on a real host
```

## New operation

`New operation` (app bar) closes the active host, opens an empty one from the shipped pack, rebuilds the router so it restarts at `/`, and leaves the GM to add agents. One host is active at a time. The first launch still seeds two demo agents.

## Adding agents

`Add agent` in the console opens a dialog with the pack's creation limits (`OperationService.creationLimits`). The UI sends the scores through `CreateAgent` and shows the engine's refusal text; it checks only that each score is a whole number and leaves every rule to the engine. Note the engine currently checks only the per-attribute range, not the total points.

## Broadcast and phone

The console's **Stat-gated broadcast** card builds a `Compare(op, Attr(key), Const(n))` condition from the attribute, comparison and value the GM picks (`BroadcastOp` mirrors the engine's `CompareOp`). **Preview** calls `engine.broadcastPreview` and lists each agent, whether they qualify and the score it read; it sends nothing. **Send** submits `BroadcastToQualifying`, so the engine decides again at send time. Only qualifying players get the line; the GM log names the recipients.

Phones use the ui_kit `PhonePanel`. Thread ids name the counterpart: `gm` for the Handler, `alias:<id>` for an agent's alias. The Handler's phone has one thread per agent (messages between the Handler and that alias); messages between two agents show in the GM log, not in the Handler's phone. A player's phone has the Handler and every other agent, built from the events that player may see. NPC parties (`PhoneNpc`) are not offered yet because the UI creates only player-owned agents.

## Demo data to replace

`SessionOperationService` seeds two agents with a score spread and `proficient` skills, and uses the fixed `demoSeed`, so every launch rolls the same dice. These are demo values, not rules; a real new-operation flow and a per-operation seed replace them.
